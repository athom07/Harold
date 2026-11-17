import Foundation

struct Source: Codable, Identifiable {
    let id: Int
    let title: String
    let url: URL
    let excerpt: String

    var domain: String {
        (url.host ?? "").replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
    }
}

struct Detail: Codable {
    let label: String
    let text: String
    let sourceIDs: [Int]
}

struct ChartPoint: Codable {
    let label: String
    let value: Double
}

struct ResearchCard: Codable, Identifiable {
    enum Kind: String, Codable, CaseIterable {
        case summary, takeaways, comparison, prosCons, metrics, chart, sources

        var label: String {
            switch self {
            case .summary: "Summary"
            case .takeaways: "Key takeaways"
            case .comparison: "Comparison"
            case .prosCons: "Pros & cons"
            case .metrics: "Key specs"
            case .chart: "Data"
            case .sources: "Sources"
            }
        }

        var icon: String {
            switch self {
            case .summary: "sparkles"
            case .takeaways: "list.bullet"
            case .comparison: "rectangle.split.2x1"
            case .prosCons: "plusminus.circle"
            case .metrics: "number.square"
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

struct Brief: Codable, Identifiable {
    var id = UUID()
    let query: String
    let cards: [ResearchCard]
    let sources: [Source]
    let isSample: Bool

    var summary: String {
        cards.first { $0.kind == .summary }?.text ?? ""
    }
}

enum ResearchStage: Equatable {
    case searching, summarizing

    var title: String {
        switch self {
        case .searching: "Finding relevant sources"
        case .summarizing: "Assembling your brief"
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
            "This question needs live research. Try a sample below or connect Tavily and Gemini in Settings."
        case .noSources:
            "No readable sources were found. Try a more specific question or inspect the search site in Harold."
        case .invalidProviderResponse:
            "Gemini didn’t return an answer. Try again."
        case .invalidBrief:
            "Gemini returned an incomplete brief. Try running the research again."
        case let .provider(name, code):
            switch code {
            case 401, 403: "\(name) rejected the request. Check your API key and account access."
            case 429, 432, 433: "\(name) reached a usage limit. Check your account or try again later."
            default: "\(name) returned an error (HTTP \(code)). Try again shortly."
            }
        case .storage:
            "Harold couldn’t save the API keys in your macOS Keychain."
        }
    }
}
