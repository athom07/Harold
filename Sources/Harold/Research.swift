import Foundation

struct Source: Codable, Identifiable, Equatable {
    let id: Int
    let title: String
    let url: URL
    let excerpt: String
    var rawByteCount: Int = 0
    var distilledWordCount: Int = 0
    var mappedClaims: [String] = []
    var mappedAdvantages: [String] = []
    var mappedDisadvantages: [String] = []

    var domain: String {
        (url.host ?? "").replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
    }
}

struct Detail: Codable, Equatable {
    let label: String
    let text: String
    let sourceIDs: [Int]
}

struct ChartPoint: Codable, Equatable {
    let label: String
    let value: Double
}

struct ResearchCard: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case summary, takeaways, comparison, prosCons, metrics, chart, sources

        var label: String {
            switch self {
            case .summary: "TL;DR Executive Summary"
            case .takeaways: "Key Takeaways"
            case .comparison: "Comparison Matrix"
            case .prosCons: "Pros & Cons"
            case .metrics: "Key Specs & Metrics"
            case .chart: "Quantitative Data"
            case .sources: "Source Citations"
            }
        }

        var icon: String {
            switch self {
            case .summary: "circle.hexagongrid.fill"
            case .takeaways: "list.bullet.rectangle"
            case .comparison: "tablecells"
            case .prosCons: "plusminus.circle"
            case .metrics: "ruler"
            case .chart: "chart.bar.xaxis"
            case .sources: "link"
            }
        }
    }

    var id: Kind { kind }
    let kind: Kind
    var title: String
    var text: String = ""
    var details: [Detail] = []
    var points: [ChartPoint] = []
    var unit: String = ""
    var sourceIDs: [Int] = []
}

struct Brief: Codable, Identifiable, Equatable {
    var id = UUID()
    let query: String
    let generatedQueries: [String]
    let cards: [ResearchCard]
    let sources: [Source]
    let isSample: Bool
    let engineLabel: String

    init(
        id: UUID = UUID(),
        query: String,
        generatedQueries: [String] = [],
        cards: [ResearchCard],
        sources: [Source],
        isSample: Bool,
        engineLabel: String = "Apple SystemLanguageModel (On-Device)"
    ) {
        self.id = id
        self.query = query
        self.generatedQueries = generatedQueries.isEmpty ? [query] : generatedQueries
        self.cards = cards
        self.sources = sources
        self.isSample = isSample
        self.engineLabel = engineLabel
    }

    var summary: String {
        cards.first { $0.kind == .summary }?.text ?? ""
    }
}

enum ResearchStage: Equatable {
    case intentDispatch
    case headlessSearch([String])
    case backgroundFetching(loaded: Int, total: Int)
    case domDistillation(sources: Int)
    case mapReduceSynthesis(mapped: Int, total: Int)
    case searching
    case summarizing

    var stepIndex: Int {
        switch self {
        case .intentDispatch: 1
        case .headlessSearch, .searching: 2
        case .backgroundFetching: 3
        case .domDistillation: 4
        case .mapReduceSynthesis, .summarizing: 5
        }
    }

    var title: String {
        switch self {
        case .intentDispatch:
            "Stage 1/5 · Converting intent into focused search queries"
        case let .headlessSearch(queries):
            "Stage 2/5 · Resolving search results in headless WKWebView (\(queries.joined(separator: " · ")))"
        case let .backgroundFetching(loaded, total):
            "Stage 3/5 · Staggered background WKWebView workers (\(loaded)/\(total) loaded, 400ms stagger)"
        case let .domDistillation(sources):
            "Stage 4/5 · Distilling DOM via Readability.js (\(sources) articles compressed to ~1,500 words)"
        case let .mapReduceSynthesis(mapped, total):
            "Stage 5/5 · Two-stage Map-Reduce synthesis (\(mapped)/\(total) @Generable fact sheets → streaming BentoGrid)"
        case .searching:
            "Stage 2/5 · Finding relevant web sources"
        case .summarizing:
            "Stage 5/5 · Synthesizing @Generable Bento Grid cards"
        }
    }
}

enum ResearchFailure: LocalizedError {
    case sampleUnavailable
    case noSources
    case invalidBrief
    case invalidProviderResponse
    case provider(String, Int)
    case storage

    var errorDescription: String? {
        switch self {
        case .sampleUnavailable:
            "This question requires live synthesis. Try a sample brief below, run on macOS 26+ with Apple Foundation Models, or configure a local MLX/Ollama or BYOK endpoint in Settings."
        case .noSources:
            "No readable sources were extracted by Readability.js. Try a more specific intent or inspect the target site in Harold."
        case .invalidProviderResponse:
            "The language model session didn’t return a valid response. Try again."
        case .invalidBrief:
            "Guided generation returned an incomplete BentoGrid payload. Try running the query again."
        case let .provider(name, code):
            switch code {
            case 401, 403: "\(name) rejected the request. Check your API key and account access."
            case 429, 432, 433: "\(name) reached a usage limit. Check your account or try again later."
            default: "\(name) returned an error (HTTP \(code)). Try again shortly."
            }
        case .storage:
            "Harold couldn’t save the provider configuration in your macOS Keychain."
        }
    }
}

