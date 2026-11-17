import React from 'react';
import { PipelineProgressState, ResearchSource } from '../types/harold';
import { Check, Cpu, FileText, Globe, Layers, Search } from 'lucide-react';

interface StreamingPipelineBarProps {
  progress: PipelineProgressState;
  sources: ResearchSource[];
  onInspectSource: (source: ResearchSource) => void;
}

const PIPELINE_STEPS = [
  {
    index: 1,
    id: 'intent_dispatch',
    label: '1. Intent Dispatch',
    sub: 'SearchIntent (@Generable)',
    icon: Search,
  },
  {
    index: 2,
    id: 'headless_search',
    label: '2. Headless Search',
    sub: 'Local WKWebView DOM ($0 API)',
    icon: Globe,
  },
  {
    index: 3,
    id: 'background_fetching',
    label: '3. Staggered Fetch',
    sub: '3 Workers · 400ms Stagger',
    icon: Layers,
  },
  {
    index: 4,
    id: 'dom_distillation',
    label: '4. Readability.js',
    sub: '~150KB HTML → ~1,500 Words',
    icon: FileText,
  },
  {
    index: 5,
    id: 'map_reduce_synthesis',
    label: '5. Map-Reduce',
    sub: 'SourceFacts → BentoGrid',
    icon: Cpu,
  },
];

export const StreamingPipelineBar: React.FC<StreamingPipelineBarProps> = ({
  progress,
  sources,
  onInspectSource,
}) => {
  return (
    <section
      aria-label="Live execution pipeline progress"
      data-testid="pipeline-progress-panel"
      className="w-full rounded-2xl border border-[#D3DFDE] bg-white/90 p-5 shadow-xs transition-all"
    >
      <div className="flex flex-wrap items-center justify-between gap-3 pb-4 border-b border-[#E5ECEB]">
        <div>
          <p className="text-xs font-mono font-medium text-[#08756E]">
            STAGE 0{progress.stageIndex} / 05 · ZERO-BACKEND EXECUTION PIPELINE
          </p>
          <h2 className="text-base font-semibold text-[#0E2421] mt-0.5">
            {progress.title}
          </h2>
        </div>
        <span className="text-xs font-mono text-[#405652] tabular-nums">
          {progress.detail}
        </span>
      </div>

      {/* 5-Stage Pipeline Stepper */}
      <div className="grid grid-cols-1 sm:grid-cols-5 gap-2.5 mt-4">
        {PIPELINE_STEPS.map((step) => {
          const isDone = progress.stageIndex > step.index;
          const isCurrent = progress.stageIndex === step.index;
          const Icon = step.icon;
          return (
            <div
              key={step.id}
              className={`rounded-xl px-3 py-2.5 border transition-colors ${
                isCurrent
                  ? 'border-[#08756E] bg-[#EAF4F3] text-[#074A53]'
                  : isDone
                  ? 'border-[#D3DFDE] bg-[#F6FAFA] text-[#0E2421]'
                  : 'border-[#E6EEEE] bg-white/60 text-[#687E79]'
              }`}
            >
              <div className="flex items-center justify-between gap-2">
                <span className="text-xs font-semibold truncate">{step.label}</span>
                {isDone ? (
                  <Check className="w-3.5 h-3.5 text-[#08756E] shrink-0" />
                ) : (
                  <Icon
                    className={`w-3.5 h-3.5 shrink-0 ${
                      isCurrent ? 'text-[#08756E]' : 'text-[#687E79]'
                    }`}
                  />
                )}
              </div>
              <p className="text-[11px] font-mono text-[#526B65] mt-1 truncate">
                {step.sub}
              </p>
            </div>
          );
        })}
      </div>

      {/* Generated Search Queries + Staggered Background Worker Telemetry */}
      {progress.generatedQueries.length > 0 && (
        <div className="mt-4 pt-3 border-t border-[#E5ECEB] flex flex-wrap items-center gap-2 text-xs text-[#405652]">
          <span className="font-semibold text-[#0E2421]">Dispatched SearchIntent:</span>
          {progress.generatedQueries.map((q, idx) => (
            <span
              key={idx}
              className="font-mono text-[#074A53] bg-[#EBF3F2] px-2.5 py-1 rounded-md"
            >
              “{q}”
            </span>
          ))}
        </div>
      )}

      {/* Live Background WKWebView Workers */}
      {sources.length > 0 && (
        <div className="mt-3 pt-3 border-t border-[#E5ECEB]">
          <div className="flex items-center justify-between text-xs text-[#526B65] mb-2">
            <span>
              Off-Screen WKWebView Workers (Residential IP · Authenticated Cookie Store)
            </span>
            <span className="font-mono tabular-nums">
              {sources.length} distilled via Readability.js
            </span>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
            {sources.map((src) => (
              <button
                key={src.id}
                type="button"
                onClick={() => onInspectSource(src)}
                className="flex items-center justify-between gap-3 text-left px-3 py-2 rounded-lg border border-[#DCE6E5] bg-[#F8FBFB] hover:border-[#08756E] transition-colors"
              >
                <div className="min-w-0">
                  <div className="flex items-center gap-2">
                    <span className="font-mono text-xs font-semibold text-[#074A53] tabular-nums">
                      0{src.id}
                    </span>
                    <span className="text-xs font-semibold text-[#0E2421] truncate">
                      {src.title}
                    </span>
                  </div>
                  <p className="text-[11px] text-[#526B65] font-mono mt-0.5 truncate">
                    {src.domain} · Worker #{src.workerId ?? ((src.id - 1) % 3) + 1} (+
                    {src.staggerDelayMs ?? (src.id - 1) * 400}ms stagger)
                  </p>
                </div>
                <span className="text-[11px] font-mono text-[#08756E] shrink-0 tabular-nums">
                  {Math.round(src.rawByteCount / 1024)}KB → {src.distilledWordCount}w
                </span>
              </button>
            ))}
          </div>
        </div>
      )}
    </section>
  );
};
