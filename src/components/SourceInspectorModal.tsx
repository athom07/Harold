import React, { useState } from 'react';
import { ResearchSource } from '../types/harold';
import { compressArticleProse } from '../utils/pipeline';
import {
  ArrowLeft,
  Bookmark,
  Cpu,
  ExternalLink,
  FileText,
  Globe,
  Lock,
  ShieldCheck,
  X,
} from 'lucide-react';

interface SourceInspectorModalProps {
  source: ResearchSource | null;
  allSources: ResearchSource[];
  isBookmarked: (url: string) => boolean;
  onToggleBookmark: (source: ResearchSource) => void;
  onSelectSource: (source: ResearchSource) => void;
  onClose: () => void;
}

export const SourceInspectorModal: React.FC<SourceInspectorModalProps> = ({
  source,
  allSources,
  isBookmarked,
  onToggleBookmark,
  onSelectSource,
  onClose,
}) => {
  const [viewMode, setViewMode] = useState<'distilled' | 'facts' | 'webview'>('distilled');

  if (!source) return null;

  const saved = isBookmarked(source.url);
  const { compressionRatioPct } = compressArticleProse(
    source.rawByteCount,
    source.excerpt,
    1500
  );

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label={`Source Inspector: ${source.title}`}
      data-testid="source-inspector-modal"
      className="fixed inset-0 z-50 flex items-center justify-center bg-[#061816]/45 backdrop-blur-xs p-4 sm:p-6"
    >
      <div className="w-full max-w-4xl max-h-[88vh] rounded-2xl border border-[#C8D8D6] bg-[#F7FAFA] shadow-2xl flex flex-col overflow-hidden">
        {/* Top Inspector Bar (Authenticated WKWebView + Readability.js Header) */}
        <div className="flex flex-wrap items-center justify-between gap-3 px-5 py-3.5 bg-[#E7F0EF] border-b border-[#D1DFDD]">
          <div className="flex items-center gap-2.5 min-w-0">
            <button
              type="button"
              onClick={onClose}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold text-[#0E2421] bg-white border border-[#CEDCDA] hover:border-[#074A53] transition-colors cursor-pointer"
            >
              <ArrowLeft className="w-3.5 h-3.5" />
              <span>Back to Bento Grid</span>
            </button>

            <div className="hidden sm:flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-white/80 border border-[#D5E1DF] text-xs text-[#405652] min-w-0 max-w-md">
              <Lock className="w-3.5 h-3.5 text-[#08756E] shrink-0" />
              <span className="font-mono truncate">{source.url}</span>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={() => onToggleBookmark(source)}
              aria-label={saved ? 'Remove bookmark' : 'Bookmark this source'}
              className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold border transition-colors cursor-pointer ${
                saved
                  ? 'bg-[#074A53] text-white border-[#074A53]'
                  : 'bg-white text-[#0E2421] border-[#CEDCDA] hover:border-[#074A53]'
              }`}
            >
              <Bookmark className="w-3.5 h-3.5" />
              <span>{saved ? 'Bookmarked' : 'Bookmark'}</span>
            </button>

            <button
              type="button"
              onClick={onClose}
              aria-label="Close source inspector"
              className="p-1.5 rounded-lg bg-white border border-[#CEDCDA] text-[#405652] hover:text-[#0E2421] cursor-pointer"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* Source Switcher Tabs + Mode Segmented Control */}
        <div className="flex flex-wrap items-center justify-between gap-3 px-5 py-3 bg-white border-b border-[#E3ECEB]">
          <div className="flex flex-wrap items-center gap-1.5">
            {allSources.map((s) => (
              <button
                key={s.id}
                type="button"
                onClick={() => onSelectSource(s)}
                className={`px-2.5 py-1 rounded-md text-xs font-mono font-semibold transition-colors cursor-pointer ${
                  s.id === source.id
                    ? 'bg-[#074A53] text-white'
                    : 'bg-[#EEF4F3] text-[#405652] hover:text-[#0E2421]'
                }`}
              >
                [0{s.id}] {s.domain}
              </button>
            ))}
          </div>

          <div className="flex items-center gap-1 p-1 rounded-lg bg-[#ECF3F2]">
            <button
              type="button"
              onClick={() => setViewMode('distilled')}
              className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-md text-xs font-semibold transition-colors cursor-pointer ${
                viewMode === 'distilled'
                  ? 'bg-white text-[#0E2421] shadow-2xs'
                  : 'text-[#526B65] hover:text-[#0E2421]'
              }`}
            >
              <FileText className="w-3.5 h-3.5" />
              <span>Readability.js Prose</span>
            </button>
            <button
              type="button"
              onClick={() => setViewMode('facts')}
              className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-md text-xs font-semibold transition-colors cursor-pointer ${
                viewMode === 'facts'
                  ? 'bg-white text-[#0E2421] shadow-2xs'
                  : 'text-[#526B65] hover:text-[#0E2421]'
              }`}
            >
              <Cpu className="w-3.5 h-3.5" />
              <span>@Generable Map Facts</span>
            </button>
            <button
              type="button"
              onClick={() => setViewMode('webview')}
              className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-md text-xs font-semibold transition-colors cursor-pointer ${
                viewMode === 'webview'
                  ? 'bg-white text-[#0E2421] shadow-2xs'
                  : 'text-[#526B65] hover:text-[#0E2421]'
              }`}
            >
              <Globe className="w-3.5 h-3.5" />
              <span>WKWebView Session</span>
            </button>
          </div>
        </div>

        {/* Main Inspector Body */}
        <div className="p-6 overflow-y-auto space-y-5 flex-1">
          {/* Provenance & Compression Strip */}
          <div className="flex flex-wrap items-center justify-between gap-2 text-xs text-[#526B65] pb-3 border-b border-[#E5ECEB]">
            <div className="flex flex-wrap items-center gap-2 font-mono tabular-nums">
              <span className="text-[#08756E] font-semibold">
                SOURCE 0{source.id} · {source.domain.toUpperCase()}
              </span>
              <span>·</span>
              <span>
                {(source.rawByteCount / 1024).toFixed(1)} KB raw HTML →{' '}
                {source.distilledWordCount.toLocaleString()} clean words ({compressionRatioPct}%
                boilerplate stripped)
              </span>
            </div>
            <div className="flex items-center gap-1.5 text-[#074A53] font-medium">
              <ShieldCheck className="w-3.5 h-3.5 text-[#08756E]" />
              <span>Residential IP · Shared Cookie Store</span>
            </div>
          </div>

          <h2 className="text-xl sm:text-2xl font-bold text-[#0E2421]">
            {source.title}
          </h2>

          {viewMode === 'distilled' && (
            <div className="space-y-4">
              <div className="rounded-xl border border-[#DCE6E5] bg-white p-5 space-y-3">
                <p className="text-xs font-mono text-[#08756E]">
                  DISTILLED ARTICLE PROSE (EVALUATED VIA READABILITY.JS IN BACKGROUND WKWEBVIEW)
                </p>
                <p className="text-[15px] leading-relaxed text-[#1F3531] whitespace-pre-line">
                  {source.excerpt}
                </p>
              </div>
            </div>
          )}

          {viewMode === 'facts' && (
            <div className="space-y-4">
              <div className="rounded-xl border border-[#DCE6E5] bg-white p-5 space-y-4">
                <div>
                  <p className="text-xs font-mono font-semibold text-[#08756E]">
                    ISOLATED MAP-STAGE PAYLOAD (@Generable struct SourceFacts)
                  </p>
                  <p className="text-xs text-[#526B65] mt-1">
                    Extracted in an independent <code className="font-mono">LanguageModelSession</code>{' '}
                    to stay well within the on-device context window before Reduce-stage BentoGrid
                    synthesis.
                  </p>
                </div>

                <div className="space-y-2">
                  <h4 className="text-xs font-bold uppercase tracking-wider text-[#0E2421]">
                    Verified Factual Claims ({source.factSheet.claims.length})
                  </h4>
                  <ul className="space-y-1.5 text-sm text-[#243B37]">
                    {source.factSheet.claims.map((claim, idx) => (
                      <li
                        key={idx}
                        className="p-2.5 rounded-lg bg-[#F4F8F8] border border-[#E3ECEB]"
                      >
                        {claim}
                      </li>
                    ))}
                  </ul>
                </div>

                {source.factSheet.advantages.length > 0 && (
                  <div className="space-y-2">
                    <h4 className="text-xs font-bold uppercase tracking-wider text-[#08756E]">
                      Supported Advantages
                    </h4>
                    <ul className="space-y-1.5 text-sm text-[#243B37]">
                      {source.factSheet.advantages.map((adv, idx) => (
                        <li
                          key={idx}
                          className="p-2.5 rounded-lg bg-[#EDF7F6] border border-[#CBE2DE]"
                        >
                          {adv}
                        </li>
                      ))}
                    </ul>
                  </div>
                )}

                {source.factSheet.disadvantages.length > 0 && (
                  <div className="space-y-2">
                    <h4 className="text-xs font-bold uppercase tracking-wider text-[#8B3D14]">
                      Supported Disadvantages
                    </h4>
                    <ul className="space-y-1.5 text-sm text-[#243B37]">
                      {source.factSheet.disadvantages.map((dis, idx) => (
                        <li
                          key={idx}
                          className="p-2.5 rounded-lg bg-[#FDF4EE] border border-[#F2D8C9]"
                        >
                          {dis}
                        </li>
                      ))}
                    </ul>
                  </div>
                )}
              </div>
            </div>
          )}

          {viewMode === 'webview' && (
            <div className="rounded-xl border border-[#DCE6E5] bg-white p-5 space-y-4">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div>
                  <h4 className="text-sm font-semibold text-[#0E2421]">
                    Authenticated WKWebView Session Inspector
                  </h4>
                  <p className="text-xs text-[#526B65] mt-0.5">
                    Uses <code className="font-mono">WKWebsiteDataStore.default()</code> to read
                    articles behind your existing logged-in subscriptions without routing cookies
                    through cloud proxies.
                  </p>
                </div>
                <a
                  href={source.url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold text-white bg-[#074A53] hover:bg-[#053840] transition-colors"
                >
                  <span>Open Original URL</span>
                  <ExternalLink className="w-3.5 h-3.5" />
                </a>
              </div>

              <div className="rounded-lg border border-[#E3ECEB] bg-[#F8FBFB] p-4 font-mono text-xs text-[#2E4440] space-y-1.5">
                <div>Worker Instance: Off-screen WKWebView (1200×900) · Worker #{source.workerId ?? 1}</div>
                <div>Stagger Offset: +{source.staggerDelayMs ?? 0}ms (bot-detection safe)</div>
                <div>Cookie Store: WKWebsiteDataStore.default() (Residential IP)</div>
                <div>DOM Extraction: Readability(document.cloneNode(true)).parse()</div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
