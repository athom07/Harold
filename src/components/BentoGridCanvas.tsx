import React, { useState } from 'react';
import { BentoCard, ResearchBrief, ResearchSource } from '../types/harold';
import {
  ArrowUpLeft,
  BarChart3,
  BookOpen,
  Check,
  ChevronDown,
  ChevronUp,
  Cpu,
  ExternalLink,
  FileText,
  Scale,
  SlidersHorizontal,
  Table2,
  Volume2,
  VolumeX,
} from 'lucide-react';

interface BentoGridCanvasProps {
  brief: ResearchBrief;
  streamingCards?: BentoCard[] | null;
  isStreaming?: boolean;
  isSpeaking: boolean;
  onToggleSpeak: () => void;
  onInspectSource: (source: ResearchSource) => void;
  onSelectFollowUp: (followUpQuery: string) => void;
  onStartFollowUpContext: (brief: ResearchBrief) => void;
}

const CARD_META: Record<
  BentoCard['kind'],
  { kicker: string; icon: React.ComponentType<{ className?: string }>; accentColor: string }
> = {
  summary: {
    kicker: 'TL;DR Executive Summary',
    icon: BookOpen,
    accentColor: 'text-[#4C3575]',
  },
  comparison: {
    kicker: 'Comparison Matrix',
    icon: Table2,
    accentColor: 'text-[#074A53]',
  },
  prosCons: {
    kicker: 'Pros & Cons Synthesis',
    icon: Scale,
    accentColor: 'text-[#8B3D14]',
  },
  metrics: {
    kicker: 'Key Specs & Metrics',
    icon: SlidersHorizontal,
    accentColor: 'text-[#08756E]',
  },
  takeaways: {
    kicker: 'Key Takeaways',
    icon: Check,
    accentColor: 'text-[#08756E]',
  },
  chart: {
    kicker: 'Quantitative Data',
    icon: BarChart3,
    accentColor: 'text-[#074A53]',
  },
  sources: {
    kicker: 'Source Citations',
    icon: FileText,
    accentColor: 'text-[#08756E]',
  },
};

export const BentoGridCanvas: React.FC<BentoGridCanvasProps> = ({
  brief,
  streamingCards,
  isStreaming = false,
  isSpeaking,
  onToggleSpeak,
  onInspectSource,
  onSelectFollowUp,
  onStartFollowUpContext,
}) => {
  const [showMapFactSheets, setShowMapFactSheets] = useState(false);

  const activeCards = isStreaming && streamingCards ? streamingCards : brief.cards;
  const totalRawKB = Math.round(
    brief.sources.reduce((acc, s) => acc + s.rawByteCount, 0) / 1024
  );
  const totalDistilledWords = brief.sources.reduce(
    (acc, s) => acc + s.distilledWordCount,
    0
  );

  const findSource = (id: number): ResearchSource | undefined =>
    brief.sources.find((s) => s.id === id);

  const renderCitationLinks = (ids: number[]) => {
    const valid = ids
      .map((id) => findSource(id))
      .filter((s): s is ResearchSource => Boolean(s));
    if (valid.length === 0) return null;
    return (
      <div className="inline-flex flex-wrap items-center gap-1.5" aria-label="Source citations">
        {valid.map((source) => (
          <button
            key={source.id}
            type="button"
            onClick={() => onInspectSource(source)}
            title={`Inspect Source ${source.id}: ${source.title} (${source.domain})`}
            aria-label={`Inspect Source ${source.id}, ${source.title}`}
            className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[11px] font-mono font-semibold text-[#074A53] bg-[#DFECEA] hover:bg-[#074A53] hover:text-white transition-colors tabular-nums cursor-pointer"
          >
            <span>[{source.id}]</span>
            <span className="hidden sm:inline max-w-[110px] truncate font-sans font-normal opacity-85">
              {source.domain}
            </span>
          </button>
        ))}
      </div>
    );
  };

  return (
    <div className="w-full space-y-5" data-testid="bento-grid-canvas">
      {/* Brief Header & Pipeline Provenance Strip */}
      <div className="flex flex-col lg:flex-row lg:items-end justify-between gap-4 pt-3 border-t border-[#D5E0DF]">
        <div className="space-y-1.5">
          <div className="flex flex-wrap items-center gap-2 text-xs text-[#526B65]">
            <span className="font-semibold text-[#074A53]">
              {brief.isSample ? 'Verified Benchmark Board' : 'Synthesized Bento Grid'}
            </span>
            <span aria-hidden="true">·</span>
            <span className="font-mono">{brief.engineLabel}</span>
            <span aria-hidden="true">·</span>
            <span className="font-mono tabular-nums">
              {brief.sources.length} sources ({totalRawKB} KB HTML →{' '}
              {totalDistilledWords.toLocaleString()} words via Readability.js)
            </span>
          </div>
          {brief.priorQuery && (
            <p className="text-xs text-[#08756E] font-medium">
              Refined from prior intent: “{brief.priorQuery}”
            </p>
          )}
          <h2 className="text-2xl sm:text-3xl font-bold tracking-tight text-[#0E2421] text-balance">
            {brief.query}
          </h2>
        </div>

        {/* Action Toolbar: Read Aloud, Inspect Map Stage, Ask Follow-Up */}
        <div className="flex flex-wrap items-center gap-2 shrink-0">
          <button
            type="button"
            onClick={() => setShowMapFactSheets((prev) => !prev)}
            className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-semibold text-[#0E2421] bg-white border border-[#D3DFDE] hover:border-[#08756E] transition-colors cursor-pointer whitespace-nowrap"
          >
            <Cpu className="w-3.5 h-3.5 text-[#08756E]" />
            <span>Map-Stage Fact Sheets ({brief.sources.length})</span>
            {showMapFactSheets ? (
              <ChevronUp className="w-3.5 h-3.5 text-[#526B65]" />
            ) : (
              <ChevronDown className="w-3.5 h-3.5 text-[#526B65]" />
            )}
          </button>

          <button
            type="button"
            onClick={onToggleSpeak}
            className={`inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-semibold transition-colors cursor-pointer whitespace-nowrap ${
              isSpeaking
                ? 'bg-[#074A53] text-white'
                : 'bg-[#DCECE9] text-[#074A53] hover:bg-[#CBE2DE]'
            }`}
          >
            {isSpeaking ? (
              <>
                <VolumeX className="w-3.5 h-3.5" />
                <span>Stop Reading</span>
              </>
            ) : (
              <>
                <Volume2 className="w-3.5 h-3.5" />
                <span>Listen to Brief</span>
              </>
            )}
          </button>

          <button
            type="button"
            onClick={() => onStartFollowUpContext(brief)}
            className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-semibold text-white bg-[#074A53] hover:bg-[#053840] transition-colors cursor-pointer whitespace-nowrap"
          >
            <ArrowUpLeft className="w-3.5 h-3.5" />
            <span>Refine Board</span>
          </button>
        </div>
      </div>

      {/* Expandable Stage 5a (Map) Per-Source @Generable SourceFacts Inspector */}
      {showMapFactSheets && (
        <section
          aria-label="Map-Stage Per-Source Fact Sheets"
          data-testid="map-stage-facts-drawer"
          className="rounded-2xl border border-[#C6D8D6] bg-[#EDF5F4] p-5 space-y-3"
        >
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <p className="text-xs font-mono font-semibold text-[#08756E]">
                STAGE 5A (MAP) · ISOLATED PER-SOURCE @Generable SourceFacts
              </p>
              <p className="text-xs text-[#405652] mt-0.5">
                Each Readability.js article (~1,500 words) is passed into an isolated{' '}
                <code className="font-mono text-[#074A53]">LanguageModelSession</code> so
                the on-device context window never overflows before Reduce assembly.
              </p>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {brief.sources.map((source) => (
              <div
                key={source.id}
                className="rounded-xl border border-[#D5E2E0] bg-white p-4 space-y-2"
              >
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <span className="text-xs font-mono font-semibold text-[#08756E]">
                      Source 0{source.id} · {source.domain}
                    </span>
                    <h4 className="text-sm font-semibold text-[#0E2421]">
                      {source.title}
                    </h4>
                  </div>
                  <button
                    type="button"
                    onClick={() => onInspectSource(source)}
                    className="text-xs font-semibold text-[#074A53] hover:underline shrink-0 cursor-pointer"
                  >
                    Inspect DOM →
                  </button>
                </div>

                <p className="text-[11px] font-mono text-[#526B65] tabular-nums">
                  Raw HTML: {(source.rawByteCount / 1024).toFixed(1)} KB → Distilled:{' '}
                  {source.distilledWordCount.toLocaleString()} words · Worker #
                  {source.workerId ?? 1}
                </p>

                {source.factSheet.claims.length > 0 && (
                  <ul className="space-y-1 text-xs text-[#2E4440] pt-1">
                    {source.factSheet.claims.map((claim, i) => (
                      <li key={i} className="flex items-start gap-1.5">
                        <span className="text-[#08756E] font-bold">·</span>
                        <span>{claim}</span>
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            ))}
          </div>
        </section>
      )}

      {/* Dynamic 12-Column Modular Bento Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-4 items-stretch">
        {activeCards.map((card) => {
          const meta = CARD_META[card.kind] || CARD_META.takeaways;
          const Icon = meta.icon;

          // Determine Bento span based on card kind
          const colSpanClass =
            card.kind === 'summary'
              ? 'lg:col-span-7'
              : card.kind === 'comparison'
              ? 'lg:col-span-5'
              : card.kind === 'prosCons'
              ? 'lg:col-span-6'
              : card.kind === 'metrics'
              ? 'lg:col-span-6'
              : card.kind === 'takeaways'
              ? 'lg:col-span-6'
              : card.kind === 'chart'
              ? 'lg:col-span-6'
              : 'lg:col-span-6';

          const surfaceStyle =
            card.kind === 'summary'
              ? 'bg-[#F2EFFA] border-[#DCD3F2]'
              : 'bg-white border-[#D7E1E0]';

          return (
            <article
              key={card.kind}
              data-testid={`bento-card-${card.kind}`}
              className={`${colSpanClass} rounded-2xl border ${surfaceStyle} p-6 flex flex-col justify-between transition-all`}
            >
              <div className="space-y-4">
                {/* Card Header */}
                <div className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <Icon className={`w-4 h-4 ${meta.accentColor}`} />
                    <span className="text-xs font-semibold tracking-wide text-[#526B65]">
                      {meta.kicker}
                    </span>
                  </div>
                  <span className="text-[11px] font-mono text-[#687E79]">
                    @Generable
                  </span>
                </div>

                <h3 className="text-lg font-bold text-[#0E2421] leading-snug">
                  {card.title}
                </h3>

                {/* Summary Card Body */}
                {card.kind === 'summary' && (
                  <p className="text-[15px] leading-relaxed text-[#243B37] font-normal">
                    {card.text}
                  </p>
                )}

                {/* Structured Rows: Comparison Matrix, Pros & Cons, Key Specs, Takeaways */}
                {(card.kind === 'comparison' ||
                  card.kind === 'prosCons' ||
                  card.kind === 'metrics' ||
                  card.kind === 'takeaways') &&
                  card.details && (
                    <div className="divide-y divide-[#E6EEEE]">
                      {card.details.map((detail, idx) => {
                        const isDisadvantage = detail.label
                          .toLowerCase()
                          .startsWith('disadvantage');
                        const isAdvantage = detail.label
                          .toLowerCase()
                          .startsWith('advantage');
                        return (
                          <div
                            key={idx}
                            className={`py-3 first:pt-1 last:pb-0 space-y-1.5 ${
                              detail.excluded ? 'opacity-55' : ''
                            }`}
                          >
                            <div className="flex flex-wrap items-center justify-between gap-2">
                              <span
                                className={`text-sm font-semibold ${
                                  detail.excluded
                                    ? 'line-through text-[#8B3D14]'
                                    : isDisadvantage
                                    ? 'text-[#8B3D14]'
                                    : isAdvantage
                                    ? 'text-[#08756E]'
                                    : 'text-[#0E2421]'
                                }`}
                              >
                                {detail.label}
                              </span>
                              {detail.meta && (
                                <span className="text-xs font-mono text-[#526B65] tabular-nums">
                                  {detail.meta}
                                </span>
                              )}
                            </div>
                            <p className="text-xs sm:text-[13px] leading-relaxed text-[#405652] tabular-nums">
                              {detail.text}
                            </p>
                            <div className="pt-0.5">
                              {renderCitationLinks(detail.sourceIDs)}
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  )}

                {/* Quantitative Data Bar Chart */}
                {card.kind === 'chart' && card.points && (
                  <div className="space-y-3 pt-1">
                    {(() => {
                      const maxVal = Math.max(...card.points.map((p) => p.value), 1);
                      return card.points.map((pt, i) => {
                        const widthPct = Math.max(
                          12,
                          Math.round((pt.value / maxVal) * 100)
                        );
                        return (
                          <div key={i} className="space-y-1">
                            <div className="flex items-center justify-between text-xs font-medium">
                              <span className="text-[#0E2421]">{pt.label}</span>
                              <span className="font-mono font-semibold text-[#074A53] tabular-nums">
                                {pt.value.toLocaleString()}
                              </span>
                            </div>
                            <div className="w-full h-2.5 rounded-full bg-[#E6EEEE] overflow-hidden">
                              <div
                                className="h-full rounded-full bg-gradient-to-r from-[#074A53] to-[#08756E]"
                                style={{ width: `${widthPct}%` }}
                              />
                            </div>
                          </div>
                        );
                      });
                    })()}
                    {card.unit && (
                      <p className="text-xs text-[#526B65] font-mono pt-1">
                        Unit: {card.unit}
                      </p>
                    )}
                  </div>
                )}

                {/* Sources Card */}
                {card.kind === 'sources' && (
                  <div className="divide-y divide-[#E6EEEE]">
                    {brief.sources.map((src) => (
                      <button
                        key={src.id}
                        type="button"
                        onClick={() => onInspectSource(src)}
                        className="w-full py-2.5 first:pt-0 last:pb-0 flex items-center justify-between gap-3 text-left group cursor-pointer"
                      >
                        <div className="flex items-center gap-3 min-w-0">
                          <span className="w-6 h-6 rounded-full bg-[#E6F0EF] text-[#074A53] font-mono text-xs font-bold flex items-center justify-center shrink-0 tabular-nums group-hover:bg-[#074A53] group-hover:text-white transition-colors">
                            {String(src.id).padStart(2, '0')}
                          </span>
                          <div className="min-w-0">
                            <p className="text-sm font-semibold text-[#0E2421] group-hover:text-[#08756E] truncate">
                              {src.title}
                            </p>
                            <p className="text-xs text-[#526B65] font-mono truncate tabular-nums">
                              {src.domain} · {src.distilledWordCount.toLocaleString()} distilled words
                            </p>
                          </div>
                        </div>
                        <ExternalLink className="w-3.5 h-3.5 text-[#526B65] group-hover:text-[#074A53] shrink-0" />
                      </button>
                    ))}
                  </div>
                )}
              </div>

              {/* Footer Citations for Summary & Chart */}
              {(card.kind === 'summary' || card.kind === 'chart') && (
                <div className="pt-4 mt-4 border-t border-black/5 flex items-center justify-between gap-2">
                  <span className="text-[11px] text-[#526B65]">Grounded sources:</span>
                  {renderCitationLinks(card.sourceIDs)}
                </div>
              )}
            </article>
          );
        })}

        {/* Progressive Streaming Skeleton Placeholders while cards are still snapping in */}
        {isStreaming &&
          Array.from({ length: Math.max(1, 4 - activeCards.length) }).map((_, idx) => (
            <div
              key={`skeleton-${idx}`}
              data-testid="bento-skeleton-card"
              className="lg:col-span-6 rounded-2xl border border-[#D7E1E0] bg-white/75 p-6 space-y-4 animate-pulse"
            >
              <div className="h-4 w-36 rounded bg-[#CBE2DE]" />
              <div className="h-6 w-3/4 rounded bg-[#DCE6E5]" />
              <div className="space-y-2.5 pt-2">
                <div className="h-3.5 w-full rounded bg-[#E6EEEE]" />
                <div className="h-3.5 w-5/6 rounded bg-[#E6EEEE]" />
                <div className="h-3.5 w-2/3 rounded bg-[#E6EEEE]" />
              </div>
            </div>
          ))}
      </div>

      {/* Conversational Follow-Up Refinement Bar */}
      {!isStreaming && brief.followUpSuggestions.length > 0 && (
        <div
          className="rounded-2xl border border-[#D3DFDE] bg-white/85 p-4 flex flex-wrap items-center justify-between gap-3"
          data-testid="conversational-followup-strip"
        >
          <div className="flex items-center gap-2 text-xs font-semibold text-[#0E2421]">
            <ArrowUpLeft className="w-4 h-4 text-[#08756E]" />
            <span>Conversational Follow-Ups (Refines Bento Grid in place):</span>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            {brief.followUpSuggestions.map((suggestion, i) => (
              <button
                key={i}
                type="button"
                onClick={() => onSelectFollowUp(suggestion)}
                className="px-3 py-1.5 rounded-lg text-xs font-medium text-[#074A53] bg-[#E8F2F1] hover:bg-[#074A53] hover:text-white transition-colors cursor-pointer"
              >
                “{suggestion}”
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};
