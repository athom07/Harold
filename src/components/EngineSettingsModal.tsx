import React, { useState } from 'react';
import { EngineProviderMode, UnifiedEngineSettings } from '../types/harold';
import { Check, Code2, Cpu, Layers, Shield, Sliders, X } from 'lucide-react';

interface EngineSettingsModalProps {
  isOpen: boolean;
  settings: UnifiedEngineSettings;
  initialTab?: 'engine' | 'architecture';
  onSave: (updated: UnifiedEngineSettings) => void;
  onClose: () => void;
}

export const EngineSettingsModal: React.FC<EngineSettingsModalProps> = ({
  isOpen,
  settings,
  initialTab = 'engine',
  onSave,
  onClose,
}) => {
  const [draft, setDraft] = useState<UnifiedEngineSettings>(settings);
  const [activeTab, setActiveTab] = useState<'engine' | 'architecture'>(initialTab);

  if (!isOpen) return null;

  const selectMode = (mode: EngineProviderMode) => {
    setDraft((prev) => ({ ...prev, mode }));
  };

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label="Unified LanguageModel & Architecture Settings"
      data-testid="engine-settings-modal"
      className="fixed inset-0 z-50 flex items-center justify-center bg-[#061816]/45 backdrop-blur-xs p-4 sm:p-6"
    >
      <div className="w-full max-w-3xl max-h-[88vh] rounded-2xl border border-[#C8D8D6] bg-[#F7FAFA] shadow-2xl flex flex-col overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between gap-4 px-6 py-4 bg-white border-b border-[#DCE6E5]">
          <div>
            <p className="text-xs font-mono font-semibold text-[#08756E]">
              ZERO-BACKEND ARCHITECTURE & POWER-USER ESCAPE HATCH
            </p>
            <h2 className="text-xl font-bold text-[#0E2421]">
              Unified LanguageModel Protocol & Pipeline Spec
            </h2>
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label="Close settings"
            className="p-2 rounded-lg border border-[#D5E1DF] text-[#405652] hover:text-[#0E2421] cursor-pointer"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Navigation Tabs */}
        <div className="flex items-center gap-2 px-6 py-2.5 bg-[#EDF4F3] border-b border-[#DCE6E5]">
          <button
            type="button"
            onClick={() => setActiveTab('engine')}
            className={`inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg text-xs font-semibold transition-colors cursor-pointer ${
              activeTab === 'engine'
                ? 'bg-white text-[#0E2421] shadow-2xs'
                : 'text-[#526B65] hover:text-[#0E2421]'
            }`}
          >
            <Sliders className="w-3.5 h-3.5" />
            <span>LanguageModel Provider & Workers</span>
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('architecture')}
            className={`inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg text-xs font-semibold transition-colors cursor-pointer ${
              activeTab === 'architecture'
                ? 'bg-white text-[#0E2421] shadow-2xs'
                : 'text-[#526B65] hover:text-[#0E2421]'
            }`}
          >
            <Code2 className="w-3.5 h-3.5" />
            <span>Under-the-Hood Architecture & @Generable Spec</span>
          </button>
        </div>

        {/* Content */}
        <div className="p-6 overflow-y-auto space-y-6 flex-1">
          {activeTab === 'engine' ? (
            <>
              {/* Provider Cards */}
              <div className="space-y-3">
                <label className="block text-xs font-bold uppercase tracking-wider text-[#405652]">
                  Select Active Synthesis Engine (ResearchLanguageModel Protocol)
                </label>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                  <button
                    type="button"
                    onClick={() => selectMode('apple_on_device')}
                    className={`text-left p-4 rounded-xl border transition-all cursor-pointer ${
                      draft.mode === 'apple_on_device'
                        ? 'border-[#074A53] bg-[#E8F3F1]'
                        : 'border-[#D7E1E0] bg-white hover:border-[#08756E]'
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <Cpu className="w-4 h-4 text-[#074A53]" />
                      {draft.mode === 'apple_on_device' && (
                        <Check className="w-4 h-4 text-[#08756E]" />
                      )}
                    </div>
                    <h3 className="text-sm font-bold text-[#0E2421] mt-2">
                      Apple Foundation Models
                    </h3>
                    <p className="text-xs text-[#526B65] mt-1">
                      On-device <code className="font-mono">SystemLanguageModel</code> (macOS 26+ Apple
                      Silicon). $0.00 token cost.
                    </p>
                  </button>

                  <button
                    type="button"
                    onClick={() => selectMode('local_mlx_ollama')}
                    className={`text-left p-4 rounded-xl border transition-all cursor-pointer ${
                      draft.mode === 'local_mlx_ollama'
                        ? 'border-[#074A53] bg-[#E8F3F1]'
                        : 'border-[#D7E1E0] bg-white hover:border-[#08756E]'
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <Layers className="w-4 h-4 text-[#074A53]" />
                      {draft.mode === 'local_mlx_ollama' && (
                        <Check className="w-4 h-4 text-[#08756E]" />
                      )}
                    </div>
                    <h3 className="text-sm font-bold text-[#0E2421]">
                      Local MLX / Ollama
                    </h3>
                    <p className="text-xs text-[#526B65] mt-1">
                      Power-user local endpoint for deep multi-tab research with Qwen/Llama models.
                    </p>
                  </button>

                  <button
                    type="button"
                    onClick={() => selectMode('cloud_byok')}
                    className={`text-left p-4 rounded-xl border transition-all cursor-pointer ${
                      draft.mode === 'cloud_byok'
                        ? 'border-[#074A53] bg-[#E8F3F1]'
                        : 'border-[#D7E1E0] bg-white hover:border-[#08756E]'
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <Shield className="w-4 h-4 text-[#074A53]" />
                      {draft.mode === 'cloud_byok' && (
                        <Check className="w-4 h-4 text-[#08756E]" />
                      )}
                    </div>
                    <h3 className="text-sm font-bold text-[#0E2421]">
                      Cloud BYOK Escape Hatch
                    </h3>
                    <p className="text-xs text-[#526B65] mt-1">
                      Swap in server-configured Gemini or Claude for extended synthesis windows.
                    </p>
                  </button>
                </div>
              </div>

              {draft.mode === 'local_mlx_ollama' && (
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 p-4 rounded-xl border border-[#D7E1E0] bg-white">
                  <div>
                    <label
                      htmlFor="local-endpoint-input"
                      className="block text-xs font-semibold text-[#0E2421] mb-1"
                    >
                      Local Endpoint URL (MLX / Ollama)
                    </label>
                    <input
                      id="local-endpoint-input"
                      type="text"
                      value={draft.localEndpoint}
                      onChange={(e) =>
                        setDraft((prev) => ({ ...prev, localEndpoint: e.target.value }))
                      }
                      className="w-full px-3 py-2 rounded-lg border border-[#CEDCDA] text-xs font-mono text-[#0E2421]"
                    />
                  </div>
                  <div>
                    <label
                      htmlFor="local-model-input"
                      className="block text-xs font-semibold text-[#0E2421] mb-1"
                    >
                      Model Identifier
                    </label>
                    <input
                      id="local-model-input"
                      type="text"
                      value={draft.localModelName}
                      onChange={(e) =>
                        setDraft((prev) => ({ ...prev, localModelName: e.target.value }))
                      }
                      className="w-full px-3 py-2 rounded-lg border border-[#CEDCDA] text-xs font-mono text-[#0E2421]"
                    />
                  </div>
                </div>
              )}

              {/* Staggered WKWebView Worker & Readability.js Controls */}
              <div className="rounded-xl border border-[#D7E1E0] bg-white p-4 space-y-4">
                <h3 className="text-sm font-bold text-[#0E2421]">
                  WKWebView Worker & Readability.js Distillation Parameters
                </h3>

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  <div>
                    <label
                      htmlFor="worker-stagger-select"
                      className="block text-xs font-semibold text-[#405652] mb-1"
                    >
                      Worker Stagger Delay
                    </label>
                    <select
                      id="worker-stagger-select"
                      value={draft.staggerIntervalMs}
                      onChange={(e) =>
                        setDraft((prev) => ({
                          ...prev,
                          staggerIntervalMs: Number(e.target.value),
                        }))
                      }
                      className="w-full px-3 py-2 rounded-lg border border-[#CEDCDA] text-xs font-medium text-[#0E2421] bg-white tabular-nums"
                    >
                      <option value={300}>300 ms (Fast)</option>
                      <option value={400}>400 ms (Default)</option>
                      <option value={500}>500 ms (Safe)</option>
                    </select>
                  </div>

                  <div>
                    <label
                      htmlFor="max-workers-select"
                      className="block text-xs font-semibold text-[#405652] mb-1"
                    >
                      Concurrent WKWebViews
                    </label>
                    <select
                      id="max-workers-select"
                      value={draft.maxConcurrentWorkers}
                      onChange={(e) =>
                        setDraft((prev) => ({
                          ...prev,
                          maxConcurrentWorkers: Number(e.target.value),
                        }))
                      }
                      className="w-full px-3 py-2 rounded-lg border border-[#CEDCDA] text-xs font-medium text-[#0E2421] bg-white tabular-nums"
                    >
                      <option value={2}>2 Workers</option>
                      <option value={3}>3 Workers (Default)</option>
                      <option value={4}>4 Workers</option>
                    </select>
                  </div>

                  <div>
                    <label
                      htmlFor="word-cap-select"
                      className="block text-xs font-semibold text-[#405652] mb-1"
                    >
                      Readability.js Word Cap
                    </label>
                    <select
                      id="word-cap-select"
                      value={draft.readabilityWordCap}
                      onChange={(e) =>
                        setDraft((prev) => ({
                          ...prev,
                          readabilityWordCap: Number(e.target.value),
                        }))
                      }
                      className="w-full px-3 py-2 rounded-lg border border-[#CEDCDA] text-xs font-medium text-[#0E2421] bg-white tabular-nums"
                    >
                      <option value={1200}>1,200 words / page</option>
                      <option value={1500}>1,500 words (Default)</option>
                      <option value={2000}>2,000 words / page</option>
                    </select>
                  </div>
                </div>
              </div>
            </>
          ) : (
            <div className="space-y-4">
              {/* Architecture Table */}
              <div className="rounded-xl border border-[#D7E1E0] bg-white overflow-hidden">
                <table className="w-full text-left border-collapse text-xs">
                  <thead>
                    <tr className="bg-[#EDF4F3] text-[#0E2421] border-b border-[#D7E1E0]">
                      <th className="py-2.5 px-3.5 font-bold">Layer</th>
                      <th className="py-2.5 px-3.5 font-bold">Technology / Component</th>
                      <th className="py-2.5 px-3.5 font-bold">Role in Harold</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-[#E6EEEE] text-[#2E4440]">
                    <tr>
                      <td className="py-2.5 px-3.5 font-semibold">UI & App Shell</td>
                      <td className="py-2.5 px-3.5 font-mono">SwiftUI (macOS)</td>
                      <td className="py-2.5 px-3.5">
                        Frameless conversational prompt bar, voice controls, and responsive Bento Grid.
                      </td>
                    </tr>
                    <tr>
                      <td className="py-2.5 px-3.5 font-semibold">Browser Engine</td>
                      <td className="py-2.5 px-3.5 font-mono">WKWebView (WebKit)</td>
                      <td className="py-2.5 px-3.5">
                        0 MB binary bloat. Executes headless searches and loads target URLs using residential IP & cookies.
                      </td>
                    </tr>
                    <tr>
                      <td className="py-2.5 px-3.5 font-semibold">Content Extraction</td>
                      <td className="py-2.5 px-3.5 font-mono">Readability.js</td>
                      <td className="py-2.5 px-3.5">
                        Injected via <code className="font-mono">evaluateJavaScript()</code> to compress ~150KB HTML into ~1,500 words.
                      </td>
                    </tr>
                    <tr>
                      <td className="py-2.5 px-3.5 font-semibold">On-Device AI</td>
                      <td className="py-2.5 px-3.5 font-mono">SystemLanguageModel</td>
                      <td className="py-2.5 px-3.5">
                        Runs locally on Apple Silicon Macs (macOS 26+) at $0.00 token cost.
                      </td>
                    </tr>
                    <tr>
                      <td className="py-2.5 px-3.5 font-semibold">Structured Binding</td>
                      <td className="py-2.5 px-3.5 font-mono">@Generable</td>
                      <td className="py-2.5 px-3.5">
                        Guided Generation of <code className="font-mono">BentoGrid</code>, <code className="font-mono">SummaryCard</code>, <code className="font-mono">ComparisonCard</code> with streaming snapshots.
                      </td>
                    </tr>
                    <tr>
                      <td className="py-2.5 px-3.5 font-semibold">Escape Hatch</td>
                      <td className="py-2.5 px-3.5 font-mono">ResearchLanguageModel</td>
                      <td className="py-2.5 px-3.5">
                        Unified protocol supporting local MLX/Ollama endpoints or BYOK (Gemini / Claude).
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>

              {/* Swift @Generable Code Snippet */}
              <div className="rounded-xl border border-[#D7E1E0] bg-[#0E2421] text-[#E6F2F0] p-4 font-mono text-xs overflow-x-auto">
                <pre>{`@available(macOS 26.0, *)
@Generable
struct BentoGrid {
    var summaryCard: SummaryCard
    @Guide(description: "Two to four modular Bento cards ordered for clarity.", .count(2...4))
    var cards: [ComparisonCard]
}`}</pre>
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between gap-3 px-6 py-3.5 bg-white border-t border-[#DCE6E5]">
          <span className="text-xs text-[#526B65]">
            Marginal server & API cost per user: <strong className="font-mono text-[#08756E]">$0.00</strong>
          </span>
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 rounded-xl text-xs font-semibold text-[#405652] hover:bg-[#EDF4F3] cursor-pointer"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={() => {
                onSave(draft);
                onClose();
              }}
              className="px-4 py-2 rounded-xl text-xs font-semibold text-white bg-[#074A53] hover:bg-[#053840] cursor-pointer"
            >
              Apply Engine Configuration
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
