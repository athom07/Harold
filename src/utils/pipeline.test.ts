import test from 'node:test';
import assert from 'node:assert/strict';
import {
  applyConversationalRefinement,
  buildSearchQueries,
  buildWebSearchResults,
  compressArticleProse,
  extractDomain,
  extractSourceFactsFromText,
  parseDirectUrl,
  validateAndGroundBentoCards,
} from './pipeline';
import { ResearchBrief, ResearchSource } from '../types/harold';

test('buildWebSearchResults produces immediate web results including PDF and extraction-resilient entries', () => {
  const results = buildWebSearchResults('Mechanical keyboards wireless latency');
  assert.ok(results.length >= 4);
  assert.ok(results.some((r) => r.hasPdfAttachment));
  assert.ok(results.some((r) => r.extractionStatus === 'extraction_failed_usable'));
  assert.ok(results.every((r) => r.domain && r.url.startsWith('https://')));
});

test('parseDirectUrl distinguishes direct URLs from natural language intents', () => {
  assert.equal(parseDirectUrl('https://www.nasa.gov/artemis'), 'https://www.nasa.gov/artemis');
  assert.equal(parseDirectUrl('seriouseats.com/best-espresso'), 'https://seriouseats.com/best-espresso');
  assert.equal(parseDirectUrl('Compare the best dual-boiler espresso machines under $2,000'), null);
  assert.equal(parseDirectUrl('ftp://files.example.com'), null);
});

test('buildSearchQueries generates 2 focused queries and incorporates prior brief context', () => {
  const initial = buildSearchQueries('Compare the best dual-boiler espresso machines under $2,000');
  assert.equal(initial.length, 2);
  assert.ok(initial[0].includes('dual-boiler espresso machines'));

  const mockPrior: ResearchBrief = {
    id: 'b1',
    query: 'Compare the best dual-boiler espresso machines under $2,000',
    generatedQueries: initial,
    cards: [],
    sources: [],
    isSample: true,
    engineLabel: 'Apple SystemLanguageModel (On-Device)',
    createdAt: '2026-11-16T00:00:00Z',
    followUpSuggestions: [],
  };

  const followUp = buildSearchQueries('Filter out anything taller than 15 inches', mockPrior);
  assert.equal(followUp.length, 2);
  assert.ok(followUp[0].toLowerCase().includes('15 inches'));
  assert.ok(followUp[0].toLowerCase().includes('dual-boiler espresso'));
});

test('compressArticleProse enforces Readability.js ~1,500 word cap and computes compression ratio', () => {
  const longText = Array.from({ length: 2100 }, (_, i) => `word${i}`).join(' ');
  const result = compressArticleProse(150_000, longText, 1500);
  assert.equal(result.wordCount, 1500);
  assert.ok(result.compressionRatioPct >= 80);
});

test('extractSourceFactsFromText extracts claims, advantages, and disadvantages for Map stage', () => {
  const sampleText =
    'The Breville Dual Boiler retails at $1,599 and measures 14.8 inches tall. ' +
    'It leads in thermal PID precision and fast 6-minute warm-up. ' +
    'However, the Rancilio Silvia Pro X stands 15.3 inches tall which can be a disadvantage under low cabinets.';
  const facts = extractSourceFactsFromText(sampleText, 'Compare dual-boiler espresso machines');
  assert.ok(facts.claims.length >= 1);
  assert.ok(facts.advantages.length >= 1);
  assert.ok(facts.disadvantages.length >= 1);
});

test('validateAndGroundBentoCards strips invalid source IDs and guarantees a sources card', () => {
  const sources: ResearchSource[] = [
    {
      id: 1,
      title: 'Serious Eats Espresso Test',
      url: 'https://www.seriouseats.com/espresso',
      domain: extractDomain('https://www.seriouseats.com/espresso'),
      excerpt: 'Dual boiler test.',
      rawByteCount: 140000,
      distilledWordCount: 1450,
      factSheet: { claims: ['Claim 1'], advantages: [], disadvantages: [] },
    },
  ];

  const grounded = validateAndGroundBentoCards(
    [
      {
        kind: 'summary',
        title: 'Executive Summary',
        text: 'Breville and Profitec lead under $2,000.',
        sourceIDs: [1, 99],
      },
    ],
    sources
  );

  assert.equal(grounded.length, 2);
  assert.deepEqual(grounded[0].sourceIDs, [1]);
  assert.equal(grounded[1].kind, 'sources');
});

test('applyConversationalRefinement filters out machines taller than 15 inches', () => {
  const prior: ResearchBrief = {
    id: 'espresso-1',
    query: 'Compare the best dual-boiler espresso machines under $2,000',
    generatedQueries: ['best dual boiler espresso machine under 2000'],
    cards: [
      {
        kind: 'summary',
        title: 'Summary',
        text: 'Original summary.',
        sourceIDs: [1],
      },
      {
        kind: 'comparison',
        title: 'Comparison Matrix',
        sourceIDs: [1],
        details: [
          {
            label: 'Breville Dual Boiler ($1,599)',
            text: 'Dual stainless boilers · Height: 14.8 in.',
            sourceIDs: [1],
          },
          {
            label: 'Rancilio Silvia Pro X ($1,990)',
            text: 'Commercial group · Height: 15.3 in.',
            sourceIDs: [1],
          },
        ],
      },
    ],
    sources: [
      {
        id: 1,
        title: 'Source 1',
        url: 'https://example.com/1',
        domain: 'example.com',
        excerpt: 'Test',
        rawByteCount: 100000,
        distilledWordCount: 1200,
        factSheet: { claims: [], advantages: [], disadvantages: [] },
      },
    ],
    isSample: true,
    engineLabel: 'Apple SystemLanguageModel (On-Device)',
    createdAt: '2026-11-16T00:00:00Z',
    followUpSuggestions: [],
  };

  const refined = applyConversationalRefinement(
    prior,
    'Filter out anything taller than 15 inches',
    'Apple SystemLanguageModel (On-Device)'
  );
  const compCard = refined.cards.find((c) => c.kind === 'comparison');
  assert.ok(compCard);
  assert.equal(compCard.details?.[0].excluded, undefined);
  assert.equal(compCard.details?.[1].excluded, true);
});
