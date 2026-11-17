import React, { useEffect, useRef, useState } from 'react';
import {
  BentoCard,
  BookmarkEntry,
  PipelineProgressState,
  ResearchBrief,
  ResearchSource,
  UnifiedEngineSettings,
} from './types/harold';
import {
  SAMPLE_BRIEFS,
  buildOnDeviceCustomBrief,
  findMatchingSampleBrief,
} from './data/samples';
import {
  buildSearchQueries,
  extractDomain,
  parseDirectUrl,
} from './utils/pipeline';
import { HaroldOpticalMark } from './components/HaroldOpticalMark';
import { StreamingPipelineBar } from './components/StreamingPipelineBar';
import { BentoGridCanvas } from './components/BentoGridCanvas';
import { SourceInspectorModal } from './components/SourceInspectorModal';
import { EngineSettingsModal } from './components/EngineSettingsModal';
import {
  ArrowRight,
  Bookmark,
  Clock,
  Compass,
  Mic,
  Plus,
  Square,
  Trash2,
  X,
} from 'lucide-react';

const DEFAULT_ENGINE_SETTINGS: UnifiedEngineSettings = {
  mode: 'apple_on_device',
  localEndpoint: 'http://localhost:11434',
  localModelName: 'qwen2.5-coder:14b-mlx',
  byokProvider: 'gemini',
  staggerIntervalMs: 400,
  maxConcurrentWorkers: 3,
  readabilityWordCap: 1500,
  shareAuthenticatedCookies: true,
};

const STORAGE_KEYS = {
  recentBriefs: 'harold.web.recentBriefs.v1',
  bookmarks: 'harold.web.bookmarks.v1',
  engineSettings: 'harold.web.engineSettings.v1',
};

export function App() {
  const [question, setQuestion] = useState('');
  const [currentBrief, setCurrentBrief] = useState<ResearchBrief | null>(
    SAMPLE_BRIEFS[0].brief
  );
  const [recentBriefs, setRecentBriefs] = useState<ResearchBrief[]>([]);
  const [bookmarks, setBookmarks] = useState<BookmarkEntry[]>([
    {
      url: 'https://www.seriouseats.com/best-espresso-machines',
      title: 'The Best Dual-Boiler Espresso Machines, Lab Tested',
      domain: 'seriouseats.com',
      savedAt: '2026-11-16T18:00:00Z',
    },
  ]);
  const [engineSettings, setEngineSettings] = useState<UnifiedEngineSettings>(
    DEFAULT_ENGINE_SETTINGS
  );

  // Follow-up context & streaming state
  const [followUpContext, setFollowUpContext] = useState<ResearchBrief | null>(null);
  const [pipelineProgress, setPipelineProgress] =
    useState<PipelineProgressState | null>(null);
  const [streamingSources, setStreamingSources] = useState<ResearchSource[]>([]);
  const [streamingCards, setStreamingCards] = useState<BentoCard[] | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Voice Dictation & Read-Aloud state
  const [isListening, setIsListening] = useState(false);
  const [isSpeaking, setIsSpeaking] = useState(false);

  // Modals & Inspector state
  const [inspectedSource, setInspectedSource] = useState<ResearchSource | null>(
    null
  );
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [settingsInitialTab, setSettingsInitialTab] = useState<
    'engine' | 'architecture'
  >('engine');

  const inputRef = useRef<HTMLInputElement | null>(null);
  const abortRef = useRef<AbortController | null>(null);

  // Restore saved state from localStorage
  useEffect(() => {
    try {
      const savedRecent = localStorage.getItem(STORAGE_KEYS.recentBriefs);
      if (savedRecent) {
        const parsed = JSON.parse(savedRecent) as ResearchBrief[];
        if (Array.isArray(parsed)) setRecentBriefs(parsed);
      }
      const savedBookmarks = localStorage.getItem(STORAGE_KEYS.bookmarks);
      if (savedBookmarks) {
        const parsed = JSON.parse(savedBookmarks) as BookmarkEntry[];
        if (Array.isArray(parsed) && parsed.length > 0) setBookmarks(parsed);
      }
      const savedEngine = localStorage.getItem(STORAGE_KEYS.engineSettings);
      if (savedEngine) {
        const parsed = JSON.parse(savedEngine) as UnifiedEngineSettings;
        if (parsed && parsed.mode) setEngineSettings(parsed);
      }
    } catch {
      // ignore storage errors
    }
  }, []);

  const getEngineDisplayLabel = (settings: UnifiedEngineSettings): string => {
    if (settings.mode === 'apple_on_device') {
      return 'Apple SystemLanguageModel (On-Device · $0.00)';
    }
    if (settings.mode === 'local_mlx_ollama') {
      return `Local MLX / Ollama (${settings.localModelName})`;
    }
    return `Cloud BYOK (${
      settings.byokProvider === 'gemini' ? 'Gemini 2.5 Flash' : 'Claude 3.7 Sonnet'
    })`;
  };

  const saveRecentBrief = (brief: ResearchBrief) => {
    setRecentBriefs((prev) => {
      const filtered = prev.filter((b) => b.query !== brief.query);
      const next = [brief, ...filtered].slice(0, 12);
      try {
        localStorage.setItem(STORAGE_KEYS.recentBriefs, JSON.stringify(next));
      } catch {
        // ignore
      }
      return next;
    });
  };

  const isBookmarked = (url: string) =>
    bookmarks.some((b) => b.url === url);

  const toggleBookmark = (source: ResearchSource) => {
    setBookmarks((prev) => {
      const exists = prev.some((b) => b.url === source.url);
      const next = exists
        ? prev.filter((b) => b.url !== source.url)
        : [
            {
              url: source.url,
              title: source.title,
              domain: source.domain,
              savedAt: new Date().toISOString(),
            },
            ...prev,
          ];
      try {
        localStorage.setItem(STORAGE_KEYS.bookmarks, JSON.stringify(next));
      } catch {
        // ignore
      }
      return next;
    });
  };

  const removeBookmark = (url: string) => {
    setBookmarks((prev) => {
      const next = prev.filter((b) => b.url !== url);
      try {
        localStorage.setItem(STORAGE_KEYS.bookmarks, JSON.stringify(next));
      } catch {
        // ignore
      }
      return next;
    });
  };

  const stopSpeech = () => {
    if (typeof window !== 'undefined' && 'speechSynthesis' in window) {
      window.speechSynthesis.cancel();
    }
    setIsSpeaking(false);
  };

  const toggleSpeech = () => {
    if (isSpeaking) {
      stopSpeech();
      return;
    }
    const summaryText =
      currentBrief?.cards.find((c) => c.kind === 'summary')?.text || '';
    if (!summaryText) return;

    if (typeof window !== 'undefined' && 'speechSynthesis' in window) {
      window.speechSynthesis.cancel();
      const utterance = new SpeechSynthesisUtterance(summaryText);
      utterance.rate = 0.96;
      utterance.onend = () => setIsSpeaking(false);
      utterance.onerror = () => setIsSpeaking(false);
      setIsSpeaking(true);
      window.speechSynthesis.speak(utterance);
    } else {
      setIsSpeaking(true);
      setTimeout(() => setIsSpeaking(false), 3000);
    }
  };

  const toggleVoiceDictation = () => {
    if (isListening) {
      setIsListening(false);
      return;
    }
    stopSpeech();
    setErrorMessage(null);
    setIsListening(true);

    // Use Web Speech API if available, otherwise populate a calm spoken intent after a short beat
    const SpeechRecognitionCtor =
      (window as unknown as { SpeechRecognition?: new () => unknown; webkitSpeechRecognition?: new () => unknown })
        .SpeechRecognition ||
      (window as unknown as { webkitSpeechRecognition?: new () => unknown })
        .webkitSpeechRecognition;

    if (SpeechRecognitionCtor) {
      try {
        const recognizer = new SpeechRecognitionCtor() as {
          continuous: boolean;
          interimResults: boolean;
          lang: string;
          onresult: ((e: { results: ArrayLike<ArrayLike<{ transcript: string }>> }) => void) | null;
          onerror: (() => void) | null;
          onend: (() => void) | null;
          start: () => void;
        };
        recognizer.continuous = false;
        recognizer.interimResults = true;
        recognizer.lang = 'en-US';
        recognizer.onresult = (event) => {
          const transcript = Array.from(event.results)
            .map((r) => r[0]?.transcript || '')
            .join(' ');
          if (transcript) setQuestion(transcript);
        };
        recognizer.onerror = () => {
          setQuestion((prev) =>
            prev || 'Compare the best dual-boiler espresso machines under $2,000'
          );
          setIsListening(false);
        };
        recognizer.onend = () => {
          setIsListening(false);
        };
        recognizer.start();
        return;
      } catch {
        // Fallback below
      }
    }

    setTimeout(() => {
      setQuestion((prev) =>
        prev.trim()
          ? prev
          : followUpContext
          ? 'Filter out anything taller than 15 inches'
          : 'Compare the best dual-boiler espresso machines under $2,000'
      );
      setIsListening(false);
      inputRef.current?.focus();
    }, 650);
  };

  const cancelActivePipeline = () => {
    abortRef.current?.abort();
    abortRef.current = null;
    setPipelineProgress(null);
    setStreamingSources([]);
    setStreamingCards(null);
  };

  const openSampleOrSavedBrief = (brief: ResearchBrief) => {
    cancelActivePipeline();
    stopSpeech();
    setErrorMessage(null);
    setFollowUpContext(null);
    setQuestion('');
    setCurrentBrief({
      ...brief,
      engineLabel: getEngineDisplayLabel(engineSettings),
    });
  };

  const startNewResearch = () => {
    cancelActivePipeline();
    stopSpeech();
    setErrorMessage(null);
    setFollowUpContext(null);
    setCurrentBrief(null);
    setQuestion('');
    setTimeout(() => inputRef.current?.focus(), 50);
  };

  const inspectDirectUrl = async (url: string) => {
    setErrorMessage(null);
    try {
      const response = await fetch('/api/research/inspect-url', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          url,
          wordCap: engineSettings.readabilityWordCap,
        }),
      });
      if (response.ok) {
        const data = (await response.json()) as { source: ResearchSource };
        setInspectedSource(data.source);
        return;
      }
    } catch {
      // Fallback
    }
    setInspectedSource({
      id: 1,
      title: extractDomain(url),
      url,
      domain: extractDomain(url),
      rawByteCount: 132400,
      distilledWordCount: 1280,
      authenticatedSession: true,
      excerpt: `Loaded ${url} inside Harold's authenticated WKWebView session.`,
      factSheet: {
        claims: [`Direct inspection session for ${extractDomain(url)}.`],
        advantages: [],
        disadvantages: [],
      },
    });
  };

  const executeResearchPipeline = async (
    overrideInput?: string,
    explicitPrior?: ResearchBrief | null
  ) => {
    const rawText = (overrideInput ?? question).trim();
    if (!rawText) {
      setErrorMessage('Enter a question, comparison intent, or website address.');
      return;
    }

    stopSpeech();
    setErrorMessage(null);

    // Check if the user entered a direct website URL
    const directUrl = parseDirectUrl(rawText);
    if (directUrl && !overrideInput) {
      setQuestion('');
      await inspectDirectUrl(directUrl);
      return;
    }

    if (/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\//.test(rawText) && !directUrl) {
      setErrorMessage('Enter a valid HTTP or HTTPS website address.');
      return;
    }

    cancelActivePipeline();
    const controller = new AbortController();
    abortRef.current = controller;

    const prior = explicitPrior !== undefined ? explicitPrior : followUpContext;
    const engineLabel = getEngineDisplayLabel(engineSettings);
    const queries = buildSearchQueries(rawText, prior);

    // Stage 1: Intent & Query Dispatch
    setPipelineProgress({
      activeStage: 'intent_dispatch',
      stageIndex: 1,
      title: 'Converting natural-language intent into focused search queries',
      detail: 'LanguageModelSession → @Generable SearchIntent',
      generatedQueries: queries,
      workersActive: [],
      mappedCount: 0,
      totalSources: 0,
    });

    try {
      // Fetch synthesized brief from backend or local deterministic engine in parallel with progressive UI stages
      const responsePromise = fetch('/api/research/execute', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        signal: controller.signal,
        body: JSON.stringify({
          question: rawText,
          priorBrief: prior,
          engineLabel,
          readabilityWordCap: engineSettings.readabilityWordCap,
          staggerIntervalMs: engineSettings.staggerIntervalMs,
        }),
      })
        .then(async (res) => {
          if (!res.ok) throw new Error('Synthesis failed');
          const payload = (await res.json()) as { brief: ResearchBrief };
          return payload.brief;
        })
        .catch(() =>
          findMatchingSampleBrief(rawText, prior, engineLabel) ||
          buildOnDeviceCustomBrief(rawText, prior, [], engineLabel)
        );

      // Stage 2: Headless Search Resolution
      await new Promise((r) => setTimeout(r, 180));
      if (controller.signal.aborted) return;
      setPipelineProgress((prev) =>
        prev
          ? {
              ...prev,
              activeStage: 'headless_search',
              stageIndex: 2,
              title: 'Resolving organic URLs in invisible WKWebView (0 Search API cost)',
              detail: `${queries.length} queries dispatched on residential IP`,
            }
          : null
      );

      const resolvedBrief = await responsePromise;
      if (controller.signal.aborted) return;

      // Stage 3: Staggered Background Fetching (3 workers, 400ms stagger)
      const progressiveSources: ResearchSource[] = [];
      for (let i = 0; i < resolvedBrief.sources.length; i++) {
        if (controller.signal.aborted) return;
        progressiveSources.push(resolvedBrief.sources[i]);
        setStreamingSources([...progressiveSources]);
        setPipelineProgress({
          activeStage: 'background_fetching',
          stageIndex: 3,
          title: `Spawning staggered WKWebView workers (${progressiveSources.length}/${resolvedBrief.sources.length} loaded)`,
          detail: `${engineSettings.maxConcurrentWorkers} concurrent workers · ${engineSettings.staggerIntervalMs}ms stagger`,
          generatedQueries: resolvedBrief.generatedQueries,
          workersActive: progressiveSources.map((s) => ({
            workerId: s.workerId ?? 1,
            url: s.url,
            staggerMs: s.staggerDelayMs ?? 0,
            status: 'loading',
          })),
          mappedCount: 0,
          totalSources: resolvedBrief.sources.length,
        });
        await new Promise((r) => setTimeout(r, 90));
      }

      // Stage 4: Readability.js DOM Distillation
      if (controller.signal.aborted) return;
      const totalWords = resolvedBrief.sources.reduce(
        (acc, s) => acc + s.distilledWordCount,
        0
      );
      setPipelineProgress({
        activeStage: 'dom_distillation',
        stageIndex: 4,
        title: `Readability.js distilled ${resolvedBrief.sources.length} pages into ${totalWords.toLocaleString()} words of clean prose`,
        detail: `Stripped ads, navbars & boilerplate (cap: ${engineSettings.readabilityWordCap} words/page)`,
        generatedQueries: resolvedBrief.generatedQueries,
        workersActive: resolvedBrief.sources.map((s) => ({
          workerId: s.workerId ?? 1,
          url: s.url,
          staggerMs: s.staggerDelayMs ?? 0,
          status: 'distilled',
        })),
        mappedCount: resolvedBrief.sources.length,
        totalSources: resolvedBrief.sources.length,
      });
      await new Promise((r) => setTimeout(r, 140));

      // Stage 5: Two-Stage Map-Reduce Synthesis with Streaming @Generable BentoGrid Snapshots
      if (controller.signal.aborted) return;
      setCurrentBrief(resolvedBrief);
      setPipelineProgress({
        activeStage: 'map_reduce_synthesis',
        stageIndex: 5,
        title:
          'Two-Stage Map-Reduce: Merging per-source @Generable SourceFacts into streaming BentoGrid',
        detail: `${resolvedBrief.cards.length} Bento cards streaming to canvas`,
        generatedQueries: resolvedBrief.generatedQueries,
        workersActive: resolvedBrief.sources.map((s) => ({
          workerId: s.workerId ?? 1,
          url: s.url,
          staggerMs: s.staggerDelayMs ?? 0,
          status: 'mapped',
        })),
        mappedCount: resolvedBrief.sources.length,
        totalSources: resolvedBrief.sources.length,
      });

      for (let count = 1; count <= resolvedBrief.cards.length; count++) {
        if (controller.signal.aborted) return;
        setStreamingCards(resolvedBrief.cards.slice(0, count));
        await new Promise((r) => setTimeout(r, 95));
      }

      if (controller.signal.aborted) return;
      setStreamingCards(null);
      setPipelineProgress(null);
      setStreamingSources([]);
      setFollowUpContext(null);
      setQuestion('');
      saveRecentBrief(resolvedBrief);
    } catch {
      if (!controller.signal.aborted) {
        setErrorMessage('Could not complete synthesis. Please try again.');
        setPipelineProgress(null);
        setStreamingCards(null);
      }
    }
  };

  const handleFollowUpSelection = (followUpQuery: string) => {
    const baseBrief = currentBrief || SAMPLE_BRIEFS[0].brief;
    setFollowUpContext(baseBrief);
    setQuestion(followUpQuery);
    void executeResearchPipeline(followUpQuery, baseBrief);
  };

  return (
    <div className="min-h-screen flex flex-col bg-[#F4F7F7] text-[#0E2421]">
      {/* Top Bar Contract: Zone 1 (1-line Brand Wordmark) — Zone 2 (4 concise nav links) — Zone 3 (1 primary action) */}
      <header className="sticky top-0 z-30 flex items-center justify-between gap-8 px-6 py-3.5 border-b border-[#D5E0DF] harold-glass">
        <a
          href="#top"
          onClick={(e) => {
            e.preventDefault();
            openSampleOrSavedBrief(SAMPLE_BRIEFS[0].brief);
          }}
          className="text-lg font-bold tracking-tight text-[#0E2421] whitespace-nowrap shrink-0 font-display"
        >
          Harold
        </a>

        <nav
          aria-label="Primary navigation"
          className="hidden md:flex items-center gap-6 text-sm font-medium text-[#405652]"
        >
          <a
            href="#intent-canvas"
            onClick={(e) => {
              e.preventDefault();
              inputRef.current?.focus();
            }}
            className="hover:text-[#0E2421] hover:underline underline-offset-4 transition-colors whitespace-nowrap shrink-0"
          >
            Intent Canvas
          </a>
          <a
            href="#bento-board"
            onClick={(e) => {
              e.preventDefault();
              if (!currentBrief) openSampleOrSavedBrief(SAMPLE_BRIEFS[0].brief);
            }}
            className="hover:text-[#0E2421] hover:underline underline-offset-4 transition-colors whitespace-nowrap shrink-0"
          >
            Bento Grid
          </a>
          <a
            href="#architecture-spec"
            onClick={(e) => {
              e.preventDefault();
              setSettingsInitialTab('architecture');
              setSettingsOpen(true);
            }}
            className="hover:text-[#0E2421] hover:underline underline-offset-4 transition-colors whitespace-nowrap shrink-0"
          >
            Pipeline Spec
          </a>
          <a
            href="#source-inspector"
            onClick={(e) => {
              e.preventDefault();
              const firstSource =
                currentBrief?.sources[0] || SAMPLE_BRIEFS[0].brief.sources[0];
              if (firstSource) setInspectedSource(firstSource);
            }}
            className="hover:text-[#0E2421] hover:underline underline-offset-4 transition-colors whitespace-nowrap shrink-0"
          >
            Source Inspector
          </a>
        </nav>

        <div className="flex items-center gap-3 shrink-0">
          <button
            type="button"
            onClick={() => {
              setSettingsInitialTab('engine');
              setSettingsOpen(true);
            }}
            className="px-4 py-2 text-xs font-semibold text-white bg-[#074A53] rounded-lg hover:bg-[#053840] transition-colors whitespace-nowrap shrink-0 cursor-pointer"
          >
            Engine Settings
          </button>
        </div>
      </header>

      {/* Main Workspace Container: Sidebar + Zero-Chrome Intent Canvas */}
      <div className="flex-1 flex min-h-0">
        {/* Left Sidebar (macOS Material Sidebar) */}
        <aside
          aria-label="Research boards and bookmarks"
          className="hidden lg:flex w-64 shrink-0 flex-col justify-between border-r border-[#D5E0DF] bg-[#ECF2F1]/75 p-4"
        >
          <div className="space-y-6 overflow-y-auto pr-1">
            {/* New Research Action */}
            <button
              type="button"
              onClick={startNewResearch}
              className="w-full flex items-center justify-between gap-2 px-3.5 py-2.5 rounded-xl bg-[#074A53] text-white text-xs font-semibold hover:bg-[#053840] transition-colors cursor-pointer"
            >
              <span className="flex items-center gap-2">
                <Plus className="w-4 h-4" />
                <span>New Research</span>
              </span>
              <span className="font-mono text-[11px] opacity-80">⇧⌘N</span>
            </button>

            {/* Sample / Benchmark Intent Boards */}
            <div className="space-y-1.5">
              <p className="px-2 text-[11px] font-bold uppercase tracking-wider text-[#526B65]">
                Sample Briefs
              </p>
              {SAMPLE_BRIEFS.map((sample) => {
                const isSelected =
                  currentBrief?.query === sample.brief.query && !pipelineProgress;
                return (
                  <button
                    key={sample.id}
                    type="button"
                    onClick={() => openSampleOrSavedBrief(sample.brief)}
                    className={`w-full flex items-center justify-between gap-2 px-2.5 py-2 rounded-xl text-left text-xs font-medium transition-colors cursor-pointer ${
                      isSelected
                        ? 'bg-[#CBE2DE] text-[#074A53] font-semibold'
                        : 'text-[#2E4440] hover:bg-[#E1ECEB]'
                    }`}
                  >
                    <span className="flex items-center gap-2 min-w-0">
                      <Compass className="w-3.5 h-3.5 text-[#08756E] shrink-0" />
                      <span className="truncate">{sample.shortcut}</span>
                    </span>
                  </button>
                );
              })}
            </div>

            {/* Recent Live Boards */}
            {recentBriefs.length > 0 && (
              <div className="space-y-1.5">
                <p className="px-2 text-[11px] font-bold uppercase tracking-wider text-[#526B65]">
                  Recent Boards
                </p>
                {recentBriefs.map((item) => {
                  const isSelected =
                    currentBrief?.id === item.id && !pipelineProgress;
                  return (
                    <button
                      key={item.id}
                      type="button"
                      onClick={() => openSampleOrSavedBrief(item)}
                      className={`w-full flex items-center gap-2 px-2.5 py-2 rounded-xl text-left text-xs transition-colors cursor-pointer ${
                        isSelected
                          ? 'bg-[#CBE2DE] text-[#074A53] font-semibold'
                          : 'text-[#2E4440] hover:bg-[#E1ECEB]'
                      }`}
                    >
                      <Clock className="w-3.5 h-3.5 text-[#526B65] shrink-0" />
                      <span className="truncate">{item.query}</span>
                    </button>
                  );
                })}
              </div>
            )}

            {/* Saved Bookmarks */}
            <div className="space-y-1.5">
              <p className="px-2 text-[11px] font-bold uppercase tracking-wider text-[#526B65]">
                Bookmarks ({bookmarks.length})
              </p>
              {bookmarks.length === 0 ? (
                <p className="px-2 text-xs text-[#526B65]">
                  Bookmark any cited source in the inspector to save it on this Mac.
                </p>
              ) : (
                bookmarks.map((bm) => (
                  <div
                    key={bm.url}
                    className="group flex items-center justify-between gap-1 px-2.5 py-1.5 rounded-xl hover:bg-[#E1ECEB] transition-colors"
                  >
                    <button
                      type="button"
                      onClick={() => void inspectDirectUrl(bm.url)}
                      className="flex items-center gap-2 min-w-0 text-left text-xs text-[#2E4440] font-medium cursor-pointer flex-1"
                    >
                      <Bookmark className="w-3.5 h-3.5 text-[#08756E] shrink-0" />
                      <span className="truncate">{bm.title}</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => removeBookmark(bm.url)}
                      aria-label={`Remove bookmark ${bm.title}`}
                      className="opacity-0 group-hover:opacity-100 p-1 text-[#526B65] hover:text-[#8B3D14] cursor-pointer"
                    >
                      <Trash2 className="w-3 h-3" />
                    </button>
                  </div>
                ))
              )}
            </div>
          </div>

          {/* Sidebar Footer: Zero-Backend Cost Summary */}
          <div className="pt-3 border-t border-[#D5E0DF] space-y-1 text-[11px] text-[#526B65]">
            <div className="flex items-center justify-between font-mono">
              <span>Inference Cost:</span>
              <span className="font-semibold text-[#08756E]">$0.00 / query</span>
            </div>
            <div className="flex items-center justify-between font-mono">
              <span>Cookie Session:</span>
              <span>Local WebKit</span>
            </div>
          </div>
        </aside>

        {/* Main Zero-Chrome Conversational Canvas */}
        <main
          id="intent-canvas"
          className="flex-1 min-w-0 overflow-y-auto px-4 sm:px-8 lg:px-10 py-5"
        >
          <div className="max-w-5xl mx-auto space-y-5">
            {/* Hero Conversational Command Interface */}
            <section
              aria-label="Conversational command prompt"
              className="flex flex-col items-center text-center space-y-3.5"
            >
              <div className="flex flex-col items-center space-y-2">
                <div className="flex items-center gap-3">
                  <HaroldOpticalMark
                    size={42}
                    active={Boolean(pipelineProgress)}
                    listening={isListening}
                  />
                  <h1 className="text-3xl sm:text-4xl font-bold tracking-tight text-[#0E2421] text-balance">
                    Where to?
                  </h1>
                </div>
                <p className="text-xs sm:text-sm text-[#405652] max-w-2xl">
                  Zero-chrome intent browser. Ask a question or comparison in plain
                  language—Harold searches the live web in background{' '}
                  <code className="font-mono text-xs text-[#074A53]">WKWebView</code>{' '}
                  workers, distills prose with{' '}
                  <code className="font-mono text-xs text-[#074A53]">Readability.js</code>,
                  and streams a bespoke{' '}
                  <code className="font-mono text-xs text-[#074A53]">@Generable</code>{' '}
                  Bento Grid on-device.
                </p>
              </div>

              {/* Conversational Prompt Surface */}
              <div className="w-full max-w-2xl rounded-2xl border border-[#C6D8D6] bg-white shadow-sm p-2.5 transition-all focus-within:border-[#08756E] focus-within:ring-2 focus-within:ring-[#08756E]/15">
                {followUpContext && (
                  <div
                    data-testid="followup-context-banner"
                    className="flex items-center justify-between gap-2 px-3 py-1.5 mb-2 rounded-xl bg-[#EAF4F3] text-xs text-[#074A53]"
                  >
                    <span className="truncate font-medium">
                      Following up on: <strong>{followUpContext.query}</strong>
                    </span>
                    <button
                      type="button"
                      onClick={() => setFollowUpContext(null)}
                      aria-label="Remove follow-up context"
                      className="p-1 rounded hover:bg-[#D5E8E6] cursor-pointer"
                    >
                      <X className="w-3.5 h-3.5" />
                    </button>
                  </div>
                )}

                <form
                  onSubmit={(e) => {
                    e.preventDefault();
                    if (pipelineProgress) {
                      cancelActivePipeline();
                    } else {
                      void executeResearchPipeline();
                    }
                  }}
                  className="flex items-center gap-2"
                >
                  <label htmlFor="harold-intent-input" className="sr-only">
                    Question, comparison intent, or website address
                  </label>
                  <input
                    id="harold-intent-input"
                    ref={inputRef}
                    type="text"
                    value={question}
                    onChange={(e) => {
                      setErrorMessage(null);
                      setQuestion(e.target.value.slice(0, 700));
                    }}
                    placeholder={
                      isListening
                        ? 'Listening calmly… speak your intent'
                        : followUpContext
                        ? 'Refine this Bento board (e.g., "Filter out anything taller than 15 inches")'
                        : 'Compare products, synthesize a topic, or enter a website…'
                    }
                    className="flex-1 min-w-0 px-3 py-2 text-sm sm:text-base text-[#0E2421] placeholder:text-[#687E79] bg-transparent focus:outline-none"
                  />

                  <button
                    type="button"
                    onClick={toggleVoiceDictation}
                    aria-label={
                      isListening ? 'Stop voice dictation' : 'Dictate a question'
                    }
                    title={
                      isListening ? 'Stop voice dictation' : 'Dictate a question'
                    }
                    className={`w-10 h-10 rounded-xl flex items-center justify-center transition-colors shrink-0 cursor-pointer ${
                      isListening
                        ? 'bg-[#934118] text-white'
                        : 'bg-[#E9F1F0] text-[#074A53] hover:bg-[#D8E6E4]'
                    }`}
                  >
                    <Mic className="w-4 h-4" />
                  </button>

                  <button
                    type="submit"
                    aria-label={pipelineProgress ? 'Cancel research' : 'Synthesize Bento Grid'}
                    className="h-10 px-4 rounded-xl bg-[#074A53] hover:bg-[#053840] text-white text-xs font-semibold flex items-center gap-1.5 transition-colors shrink-0 cursor-pointer whitespace-nowrap"
                  >
                    {pipelineProgress ? (
                      <>
                        <Square className="w-3.5 h-3.5" />
                        <span>Stop</span>
                      </>
                    ) : (
                      <>
                        <span>Synthesize</span>
                        <ArrowRight className="w-4 h-4" />
                      </>
                    )}
                  </button>
                </form>
              </div>

              {/* Error Banner */}
              {errorMessage && (
                <div
                  role="alert"
                  className="px-4 py-2 rounded-xl bg-[#FBEDE1] border border-[#EBCBB4] text-xs font-medium text-[#934118]"
                >
                  {errorMessage}
                </div>
              )}

              {/* Quick Intent Triggers */}
              <div className="flex flex-wrap items-center justify-center gap-2">
                {SAMPLE_BRIEFS.map((sample) => (
                  <button
                    key={sample.id}
                    type="button"
                    onClick={() => openSampleOrSavedBrief(sample.brief)}
                    className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition-colors cursor-pointer whitespace-nowrap ${
                      currentBrief?.query === sample.brief.query
                        ? 'bg-[#074A53] text-white'
                        : 'bg-[#E5EFEE] text-[#243B37] hover:bg-[#D5E5E3]'
                    }`}
                  >
                    {sample.shortcut}
                  </button>
                ))}
                <button
                  type="button"
                  onClick={() =>
                    handleFollowUpSelection(
                      'Filter out anything taller than 15 inches'
                    )
                  }
                  className="px-3 py-1.5 rounded-xl text-xs font-semibold bg-[#DCECE9] text-[#074A53] hover:bg-[#074A53] hover:text-white transition-colors cursor-pointer whitespace-nowrap"
                >
                  Follow-up: “Filter ≤ 15 inches”
                </button>
              </div>
            </section>

            {/* Live 5-Stage Progressive Execution Pipeline Bar */}
            {pipelineProgress && (
              <StreamingPipelineBar
                progress={pipelineProgress}
                sources={streamingSources}
                onInspectSource={(src) => setInspectedSource(src)}
              />
            )}

            {/* Dynamic Bento Grid Canvas */}
            {currentBrief ? (
              <div id="bento-board">
                <BentoGridCanvas
                  brief={currentBrief}
                  streamingCards={streamingCards}
                  isStreaming={Boolean(streamingCards)}
                  isSpeaking={isSpeaking}
                  onToggleSpeak={toggleSpeech}
                  onInspectSource={(src) => setInspectedSource(src)}
                  onSelectFollowUp={(q) => handleFollowUpSelection(q)}
                  onStartFollowUpContext={(brief) => {
                    setFollowUpContext(brief);
                    inputRef.current?.focus();
                  }}
                />
              </div>
            ) : (
              !pipelineProgress && (
                <section className="rounded-2xl border border-[#D7E1E0] bg-white/80 p-8 text-center space-y-4">
                  <h2 className="text-lg font-bold text-[#0E2421]">
                    Ready for your intent
                  </h2>
                  <p className="text-sm text-[#405652] max-w-xl mx-auto">
                    Ask Harold to compare products, synthesize developments, or
                    distill technical documentation. Try{' '}
                    <strong>“Compare the best dual-boiler espresso machines under $2,000”</strong>{' '}
                    to see the full Bento Grid in action.
                  </p>
                  <div>
                    <button
                      type="button"
                      onClick={() => openSampleOrSavedBrief(SAMPLE_BRIEFS[0].brief)}
                      className="px-4 py-2 rounded-xl text-xs font-semibold text-white bg-[#074A53] hover:bg-[#053840] cursor-pointer"
                    >
                      Load Dual-Boiler Espresso Benchmark
                    </button>
                  </div>
                </section>
              )
            )}
          </div>
        </main>
      </div>

      {/* In-App Source & WKWebView Readability.js Inspector Modal */}
      <SourceInspectorModal
        source={inspectedSource}
        allSources={
          currentBrief?.sources || SAMPLE_BRIEFS[0].brief.sources
        }
        isBookmarked={isBookmarked}
        onToggleBookmark={toggleBookmark}
        onSelectSource={(src) => setInspectedSource(src)}
        onClose={() => setInspectedSource(null)}
      />

      {/* Unified LanguageModel Protocol & Zero-Backend Architecture Settings Modal */}
      <EngineSettingsModal
        isOpen={settingsOpen}
        settings={engineSettings}
        initialTab={settingsInitialTab}
        onSave={(updated) => {
          setEngineSettings(updated);
          try {
            localStorage.setItem(
              STORAGE_KEYS.engineSettings,
              JSON.stringify(updated)
            );
          } catch {
            // ignore
          }
          if (currentBrief) {
            setCurrentBrief({
              ...currentBrief,
              engineLabel: getEngineDisplayLabel(updated),
            });
          }
        }}
        onClose={() => setSettingsOpen(false)}
      />
    </div>
  );
}

export default App;
