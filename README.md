# Harold — Intent-Driven Web Browser

Harold is a native macOS intent-driven web browser with no URL bar, no tab clutter, and zero cloud inference costs. Inspired by HAL 9000 from *2001: A Space Odyssey*, Harold replaces manual link-hunting and tab-switching with a conversational command interface that autonomously searches the live web, synthesizes multiple sources on-device, and renders a bespoke, interactive **Bento Grid** tailored to your query.

## 1. Core Concept & User Experience

- **Zero-Chrome, Intent-First Interface**: Opens directly to a calm, minimal conversational canvas supporting both text and spoken voice interaction—no address bar, bookmarks bar, or tab strip clutter.
- **Multi-Source Synthesis**: Ask in plain language (e.g., *"Compare the best dual-boiler espresso machines under $2,000"* or *"Why are we going back to the Moon?"*).
- **Dynamic Bento Box Canvas**: Dynamically assembles a modular Bento Grid of native cards (**TL;DR Executive Summary**, **Comparison Matrix**, **Pros & Cons**, **Key Specs & Metrics**, **Quantitative Data Chart**, and **Source Citations**).
- **Progressive Streaming UI**: As background pages resolve and summarize in real time, skeleton placeholders snap incrementally into live, populated Bento cards.
- **Conversational Follow-Ups & Source Inspection**: Refine any Bento board conversationally (e.g., *"Filter out anything taller than 15 inches"*) or click any card's citation badge (`[1]`) to inspect the distilled Readability.js article, Map-stage `@Generable` fact sheet, or live webpage.

## 2. Under-the-Hood Architecture (Zero-Backend Design)

| Layer | Technology / Component | Role in Harold |
| :--- | :--- | :--- |
| **UI & App Shell** | SwiftUI (macOS) / React Web Shell | Renders the frameless conversational prompt bar, voice controls, and responsive Bento Box layout. |
| **Browser Engine** | `WKWebView` (WebKit) | Executes searches and loads target URLs in invisible background instances using the user's residential IP and authenticated session cookies. |
| **Content Extraction** | `Readability.js` (`@mozilla/readability`) | Injected into each loaded background page to strip ads, navbars, and boilerplate, distilling ~150 KB of raw HTML into ~1,500 words of clean article prose. |
| **On-Device AI** | Apple Foundation Models (`SystemLanguageModel`) | Runs locally on Apple Silicon Macs (macOS 26+) at $0.00 token cost to summarize pages and generate structured UI payloads. |
| **Structured UI Binding** | Guided Generation (`@Generable`) | Forces the on-device LLM to output strictly typed Swift structs (`BentoGrid`, `SummaryCard`, `ComparisonCard`, `SourceFacts`) with streaming snapshots. |
| **Power-User Escape Hatch** | Unified `ResearchLanguageModel` Protocol | Optional BYOK (Gemini, Claude) or local endpoint (`MLX` / `Ollama`) setting for deep multi-tab research. |

## 3. Execution Pipeline (5 Stages)

1. **Intent & Query Dispatch**: Converts the user's natural-language intent (plus optional follow-up context) into 1–2 focused search queries via `SearchIntent`.
2. **Headless Search Resolution**: Loads a search query on the user's network and extracts the top 4–5 organic result URLs via DOM selectors—eliminating recurring Search API fees.
3. **Staggered Background Fetching**: Spawns up to 3 concurrent off-screen `WKWebView` workers staggered by 300–500ms (400ms default) sharing the user's cookie store.
4. **DOM Distillation**: `Readability.js` extracts core prose and metadata (~1,500 words) while recording byte-to-word compression ratios.
5. **Two-Stage Map-Reduce Synthesis**:
   - **Map (Per Source)**: Each distilled page is passed into an isolated `LanguageModelSession` to extract a compact `@Generable SourceFacts` sheet (claims, advantages, disadvantages, URL).
   - **Reduce (Bento Assembly)**: The compact fact sheets are merged in a final `LanguageModelSession` using Guided Generation and Streaming Snapshots (`BentoGrid`), animating each card onto the canvas as its properties populate.

## 4. Build & Launch

### Interactive Web Preview (AI Studio / Node.js)

```sh
npm install
npm run dev
```

### Native macOS App Bundle (macOS 14+ / macOS 26+ for `FoundationModels`)

```sh
./Scripts/build-app.sh
open dist/Harold.app
```

