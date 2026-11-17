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

export type BrowserPageKind = 'search_results' | 'article' | 'pdf' | 'signin' | 'webapp';

export interface WebSearchResultItem {
  id: number;
  title: string;
  url: string;
  domain: string;
  snippet: string;
  publishedDate?: string;
  hasPdfAttachment?: boolean;
  pdfFilename?: string;
  requiresSignIn?: boolean;
  extractionStatus: 'distilled' | 'extraction_failed_usable' | 'live';
}

export interface BrowserPageTab {
  id: string;
  url: string;
  title: string;
  domain: string;
  kind: BrowserPageKind;
  searchQuery?: string;
  searchResults?: WebSearchResultItem[];
  source?: ResearchSource;
  historyBackStack: string[];
  historyForwardStack: string[];
  openedFromTabId?: string;
  isPopupWindow?: boolean;
  createdAt: string;
  lastVisitedAt: string;
  extractionNote?: string;
  uploadedFiles?: { name: string; sizeBytes: number; uploadedAt: string }[];
}

export interface BrowserHistoryItem {
  id: string;
  url: string;
  title: string;
  domain: string;
  visitedAt: string;
  kind: BrowserPageKind;
}

export interface BrowserDownloadItem {
  id: string;
  filename: string;
  sourceUrl: string;
  domain: string;
  sizeBytes: number;
  mimeType: string;
  status: 'completed' | 'downloading';
  savedPath: string;
  downloadedAt: string;
}

export interface SiteAuthSession {
  domain: string;
  accountEmail: string;
  status: 'signed_in' | 'expired' | 'signed_out';
  cookieName: string;
  signedInAt: string;
  expiresAt: string;
}

export type SitePermissionType = 'camera' | 'microphone' | 'notifications' | 'geolocation';

export interface SitePermissionRecord {
  domain: string;
  permission: SitePermissionType;
  decision: 'allow' | 'deny' | 'prompt';
  updatedAt: string;
}

export interface DefaultBrowserConfig {
  isDefaultBrowser: boolean;
  registeredSchemes: string[];
  bundleIdentifier: string;
  codeSignatureStatus: 'Developer ID Application (Signed & Notarized)' | 'Ad-Hoc Local Build';
  lastExternalLinkOpened?: {
    sourceApp: 'Mail' | 'Messages' | 'Finder' | 'Terminal';
    url: string;
    appStateWhenClicked: 'running' | 'closed_cold_launch';
    openedAt: string;
  };
}

