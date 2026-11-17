export type BentoCardKind =
  | 'summary'
  | 'comparison'
  | 'prosCons'
  | 'metrics'
  | 'takeaways'
  | 'chart'
  | 'sources';

export interface SourceFactSheet {
  claims: string[];
  advantages: string[];
  disadvantages: string[];
}

export interface ResearchSource {
  id: number;
  title: string;
  url: string;
  domain: string;
  excerpt: string;
  rawByteCount: number;
  distilledWordCount: number;
  authenticatedSession?: boolean;
  workerId?: number;
  staggerDelayMs?: number;
  factSheet: SourceFactSheet;
}

export interface BentoDetailRow {
  label: string;
  text: string;
  sourceIDs: number[];
  meta?: string;
  excluded?: boolean;
}

export interface BentoChartPoint {
  label: string;
  value: number;
}

export interface BentoCard {
  kind: BentoCardKind;
  title: string;
  text?: string;
  details?: BentoDetailRow[];
  points?: BentoChartPoint[];
  unit?: string;
  sourceIDs: number[];
}

export interface ResearchBrief {
  id: string;
  query: string;
  priorQuery?: string;
  generatedQueries: string[];
  cards: BentoCard[];
  sources: ResearchSource[];
  isSample: boolean;
  engineLabel: string;
  createdAt: string;
  followUpSuggestions: string[];
}

export type PipelineStageId =
  | 'intent_dispatch'
  | 'headless_search'
  | 'background_fetching'
  | 'dom_distillation'
  | 'map_reduce_synthesis';

export interface PipelineProgressState {
  activeStage: PipelineStageId;
  stageIndex: number; // 1..5
  title: string;
  detail: string;
  generatedQueries: string[];
  workersActive: { workerId: number; url: string; staggerMs: number; status: 'queued' | 'loading' | 'distilled' | 'mapped' }[];
  mappedCount: number;
  totalSources: number;
}

export type EngineProviderMode = 'apple_on_device' | 'local_mlx_ollama' | 'cloud_byok';

export interface UnifiedEngineSettings {
  mode: EngineProviderMode;
  localEndpoint: string;
  localModelName: string;
  byokProvider: 'gemini' | 'claude';
  staggerIntervalMs: number;
  maxConcurrentWorkers: number;
  readabilityWordCap: number;
  shareAuthenticatedCookies: boolean;
}

export interface BookmarkEntry {
  url: string;
  title: string;
  domain: string;
  savedAt: string;
}
