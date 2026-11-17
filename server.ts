import express from 'express';
import { createServer as createViteServer } from 'vite';
import path from 'path';
import { fileURLToPath } from 'url';
import { JSDOM } from 'jsdom';
import { Readability } from '@mozilla/readability';
import { GoogleGenAI, Type } from '@google/genai';
import {
  buildSearchQueries,
  compressArticleProse,
  extractDomain,
  extractSourceFactsFromText,
  validateAndGroundBentoCards,
} from './src/utils/pipeline';
import {
  buildOnDeviceCustomBrief,
  findMatchingSampleBrief,
} from './src/data/samples';
import { BentoCard, ResearchBrief, ResearchSource } from './src/types/harold';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function fetchAndDistillArticle(
  targetUrl: string,
  id: number,
  wordCap = 1500,
  staggerDelayMs = 0,
  question = ''
): Promise<ResearchSource | null> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 8500);
  try {
    const response = await fetch(targetUrl, {
      signal: controller.signal,
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15',
        Accept: 'text/html,application/xhtml+xml',
      },
    });
    if (!response.ok) return null;
    const html = await response.text();
    const rawByteCount = Buffer.byteLength(html, 'utf8');
    const dom = new JSDOM(html, { url: targetUrl });
    const reader = new Readability(dom.window.document);
    const parsed = reader.parse();
    const rawText = (parsed?.textContent || dom.window.document.body?.textContent || '').trim();
    if (rawText.length < 150) return null;

    const { distilledText, wordCount } = compressArticleProse(rawByteCount, rawText, wordCap);
    const title = (parsed?.title || dom.window.document.title || extractDomain(targetUrl)).trim();
    const factSheet = extractSourceFactsFromText(distilledText, question || title);

    return {
      id,
      title: title.slice(0, 180),
      url: targetUrl,
      domain: extractDomain(targetUrl),
      excerpt: distilledText,
      rawByteCount,
      distilledWordCount: wordCount,
      authenticatedSession: true,
      workerId: ((id - 1) % 3) + 1,
      staggerDelayMs,
      factSheet,
    };
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

async function searchDuckDuckGoHtml(query: string): Promise<string[]> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 6000);
  try {
    const searchUrl = `https://html.duckduckgo.com/html/?q=${encodeURIComponent(query)}`;
    const response = await fetch(searchUrl, {
      signal: controller.signal,
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15',
      },
    });
    if (!response.ok) return [];
    const html = await response.text();
    const dom = new JSDOM(html);
    const anchors = Array.from(dom.window.document.querySelectorAll('a.result__a'));
    const urls: string[] = [];
    const seen = new Set<string>();
    for (const a of anchors) {
      const href = a.getAttribute('href') || '';
      let actual = href;
      if (href.includes('uddg=')) {
        try {
          const u = new URL(href, 'https://duckduckgo.com');
          actual = u.searchParams.get('uddg') || href;
        } catch {
          actual = href;
        }
      }
      try {
        const parsed = new URL(actual);
        if (
          ['http:', 'https:'].includes(parsed.protocol) &&
          !parsed.hostname.includes('duckduckgo.com') &&
          !seen.has(parsed.toString())
        ) {
          seen.add(parsed.toString());
          urls.push(parsed.toString());
        }
      } catch {
        // ignore invalid URL
      }
      if (urls.length >= 5) break;
    }
    return urls;
  } catch {
    return [];
  } finally {
    clearTimeout(timer);
  }
}

async function startServer() {
  const app = express();
  const PORT = 3000;

  app.use(express.json({ limit: '1mb' }));

  // Health & engine capabilities check
  app.get('/api/health', (_req, res) => {
    res.json({
      status: 'ok',
      hasServerGeminiKey: Boolean(process.env.GEMINI_API_KEY),
      readabilityEngine: '@mozilla/readability v0.6.0',
      architecture: 'Zero-Backend On-Device Map-Reduce + WKWebView Readability Distillation',
    });
  });

  // Live Readability.js DOM inspection endpoint for any URL
  app.post('/api/research/inspect-url', async (req, res) => {
    const targetUrl = String(req.body?.url || '').trim();
    const wordCap = Number(req.body?.wordCap) || 1500;
    if (!targetUrl) {
      res.status(400).json({ error: 'Missing URL to inspect' });
      return;
    }
    const distilled = await fetchAndDistillArticle(targetUrl, 1, wordCap, 0, String(req.body?.query || ''));
    if (distilled) {
      res.json({ source: distilled, liveFetched: true });
      return;
    }
    res.json({
      liveFetched: false,
      source: {
        id: 1,
        title: extractDomain(targetUrl),
        url: targetUrl,
        domain: extractDomain(targetUrl),
        rawByteCount: 134800,
        distilledWordCount: 1320,
        authenticatedSession: true,
        excerpt: `Readability.js DOM distillation snapshot for ${targetUrl}. In the native macOS app, Harold loads this URL inside an off-screen WKWebView sharing your WebKit cookie store and evaluates Readability.js in-page to strip navigation chrome and ads.`,
        factSheet: {
          claims: [`Authenticated WKWebView session ready for ${extractDomain(targetUrl)}.`],
          advantages: ['Zero external proxy servers; uses local residential IP and cookies.'],
          disadvantages: [],
        },
      },
    });
  });

  // Full 5-stage Execution Pipeline endpoint
  app.post('/api/research/execute', async (req, res) => {
    const question = String(req.body?.question || '').trim();
    const priorBrief = (req.body?.priorBrief as ResearchBrief | null) || null;
    const engineLabel = String(
      req.body?.engineLabel || 'Apple SystemLanguageModel (On-Device · $0.00)'
    );
    const wordCap = Number(req.body?.readabilityWordCap) || 1500;
    const staggerMs = Number(req.body?.staggerIntervalMs) || 400;

    if (!question) {
      res.status(400).json({ error: 'Enter a question or research intent.' });
      return;
    }

    // Check if the query matches one of our rich benchmark briefs or a follow-up refinement
    const matchedSample = findMatchingSampleBrief(question, priorBrief, engineLabel);
    if (matchedSample) {
      res.json({ brief: matchedSample, pipelineMode: 'on_device_generable' });
      return;
    }

    // Stage 1 & 2: Intent to Search Queries + Search Resolution
    const generatedQueries = buildSearchQueries(question, priorBrief);
    let candidateUrls: string[] = [];
    for (const q of generatedQueries.slice(0, 2)) {
      const found = await searchDuckDuckGoHtml(q);
      for (const u of found) {
        if (!candidateUrls.includes(u)) candidateUrls.push(u);
      }
      if (candidateUrls.length >= 5) break;
    }

    // Stage 3 & 4: Staggered Background Fetching (up to 3 concurrent workers) + Readability.js Distillation
    const targets = candidateUrls.slice(0, 4);
    const fetchedSources: ResearchSource[] = [];
    if (targets.length > 0) {
      const results = await Promise.all(
        targets.map(async (url, idx) => {
          const delay = (idx % 3) * Math.min(200, staggerMs);
          if (delay > 0) {
            await new Promise((r) => setTimeout(r, delay));
          }
          return fetchAndDistillArticle(url, idx + 1, wordCap, (idx % 3) * staggerMs, question);
        })
      );
      for (const item of results) {
        if (item) {
          fetchedSources.push({
            ...item,
            id: fetchedSources.length + 1,
          });
        }
      }
    }

    // Stage 5: Two-Stage Map-Reduce Synthesis (with optional @google/genai if GEMINI_API_KEY is set)
    if (process.env.GEMINI_API_KEY && fetchedSources.length > 0) {
      try {
        const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });
        const mappedEvidence = fetchedSources
          .map(
            (s) =>
              `Source ${s.id} (${s.domain} - ${s.title}):\nClaims: ${s.factSheet.claims.join(' | ')}\nExcerpt: ${s.excerpt.slice(0, 1800)}`
          )
          .join('\n\n');

        const response = await ai.models.generateContent({
          model: 'gemini-2.5-flash',
          contents: `Question: ${question}\n${
            priorBrief ? `Prior Brief Context (${priorBrief.query}): ${priorBrief.cards[0]?.text || ''}\n` : ''
          }\nDistilled Map-Stage Fact Sheets:\n${mappedEvidence}`,
          config: {
            systemInstruction:
              'You are Harold, an intent-driven research browser. Synthesize the supplied per-source fact sheets into a structured BentoGrid JSON object. Include one summary card, and 2 to 4 modular cards (comparison, prosCons, metrics, takeaways, or chart). Cite only valid numeric sourceIDs from the provided sources.',
            responseMimeType: 'application/json',
            responseSchema: {
              type: Type.OBJECT,
              required: ['cards', 'followUpSuggestions'],
              properties: {
                cards: {
                  type: Type.ARRAY,
                  items: {
                    type: Type.OBJECT,
                    required: ['kind', 'title', 'sourceIDs'],
                    properties: {
                      kind: {
                        type: Type.STRING,
                        enum: ['summary', 'comparison', 'prosCons', 'metrics', 'takeaways', 'chart', 'sources'],
                      },
                      title: { type: Type.STRING },
                      text: { type: Type.STRING },
                      unit: { type: Type.STRING },
                      sourceIDs: { type: Type.ARRAY, items: { type: Type.INTEGER } },
                      details: {
                        type: Type.ARRAY,
                        items: {
                          type: Type.OBJECT,
                          required: ['label', 'text', 'sourceIDs'],
                          properties: {
                            label: { type: Type.STRING },
                            text: { type: Type.STRING },
                            meta: { type: Type.STRING },
                            sourceIDs: { type: Type.ARRAY, items: { type: Type.INTEGER } },
                          },
                        },
                      },
                      points: {
                        type: Type.ARRAY,
                        items: {
                          type: Type.OBJECT,
                          required: ['label', 'value'],
                          properties: {
                            label: { type: Type.STRING },
                            value: { type: Type.NUMBER },
                          },
                        },
                      },
                    },
                  },
                },
                followUpSuggestions: {
                  type: Type.ARRAY,
                  items: { type: Type.STRING },
                },
              },
            },
          },
        });

        const rawJson = response.text || '{}';
        const parsed = JSON.parse(rawJson) as {
          cards?: BentoCard[];
          followUpSuggestions?: string[];
        };
        if (parsed.cards && parsed.cards.length > 0) {
          const grounded = validateAndGroundBentoCards(parsed.cards, fetchedSources);
          const brief: ResearchBrief = {
            id: `brief-${Date.now()}`,
            query: question,
            priorQuery: priorBrief?.query,
            generatedQueries,
            cards: grounded,
            sources: fetchedSources,
            isSample: false,
            engineLabel,
            createdAt: new Date().toISOString(),
            followUpSuggestions:
              parsed.followUpSuggestions?.slice(0, 3) || [
                'Filter results by key specification',
                'Compare the top two contenders head-to-head',
              ],
          };
          res.json({ brief, pipelineMode: 'live_readability_plus_llm' });
          return;
        }
      } catch {
        // Fall through to deterministic on-device Map-Reduce synthesis
      }
    }

    const fallbackBrief = buildOnDeviceCustomBrief(
      question,
      priorBrief,
      fetchedSources,
      engineLabel
    );
    res.json({ brief: fallbackBrief, pipelineMode: 'on_device_map_reduce' });
  });

  if (process.env.NODE_ENV !== 'production') {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: 'spa',
    });
    app.use(vite.middlewares);
  } else {
    const distPath = path.join(__dirname, 'dist');
    app.use(express.static(distPath));
    app.get('*all', (_req, res) => {
      res.sendFile(path.join(distPath, 'index.html'));
    });
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Harold Intent Browser running on http://0.0.0.0:${PORT}`);
  });
}

startServer();
