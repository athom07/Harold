import SwiftUI

@MainActor
final class Workspace: ObservableObject {
    @Published var question = ""
    @Published private(set) var current: Brief? = nil
    @Published private(set) var recent: [Brief] = []
    @Published private(set) var keys = ResearchKeys.load()
    @Published private(set) var stage: ResearchStage?
    @Published private(set) var pendingQuestion = ""
    @Published private(set) var foundSources: [Source] = []
    @Published private(set) var error: String?
    @Published private(set) var context: Brief?

    @Published private(set) var streamingCards: [ResearchCard] = []
    var canResearch: Bool {
        if #available(macOS 26.0, *) { return true }
        return keys.isConfigured
    }

    private static let historyKey = "harold.researchHistory"
    private var task: Task<Void, Never>?

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.historyKey),
           let history = try? JSONDecoder().decode([Brief].self, from: data) {
            recent = history
        }
    }

    func saveKeys(_ replacement: ResearchKeys) throws {
        try replacement.save()
        keys = replacement
    }

    func open(_ brief: Brief) {
        cancel()
        error = nil
        context = nil
        question = ""
        current = brief
    }

    func newResearch() {
        cancel()
        current = nil
        context = nil
        question = ""
        error = nil
    }

    func followUp(on brief: Brief) {
        context = brief
        error = nil
    }

    func clearContext() {
        context = nil
    }

    func cancel() {
        task?.cancel()
        task = nil
        stage = nil
        pendingQuestion = ""
        foundSources = []
        streamingCards = []
    }

    func submit(_ input: String? = nil) {
        let query = (input ?? question).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, stage == nil else { return }
        let prior = input == nil ? context : nil
        let credentials = keys
        let matchedSample = Samples.matching(query)
        if !canResearch, matchedSample == nil {
            error = ResearchFailure.sampleUnavailable.localizedDescription
            return
        }
        error = nil
        pendingQuestion = query
        stage = .intentDispatch
        let service = ResearchService()

        task = Task {
            do {
                let result: Brief
                if let sample = matchedSample, !credentials.isConfigured {
                    stage = .headlessSearch(sample.generatedQueries)
                    try await Task.sleep(for: .milliseconds(250))
                    foundSources = sample.sources
                    stage = .domDistillation(sources: sample.sources.count)
                    try await Task.sleep(for: .milliseconds(250))
                    stage = .mapReduceSynthesis(mapped: sample.sources.count, total: sample.sources.count)
                    for count in 1...sample.cards.count {
                        try Task.checkCancellation()
                        streamingCards = Array(sample.cards.prefix(count))
                        try await Task.sleep(for: .milliseconds(140))
                    }
                    result = sample
                } else if #available(macOS 26.0, *) {
                    result = try await LocalResearch().run(
                        question: query,
                        prior: prior,
                        stageChanged: { nextStage in
                            guard !Task.isCancelled else { return }
                            self.stage = nextStage
                        },
                        sourcesChanged: { sources in
                            guard !Task.isCancelled else { return }
                            self.foundSources = sources
                        },
                        cardsChanged: { cards in
                            guard !Task.isCancelled else { return }
                            self.streamingCards = cards
                        }
                    )
                } else if credentials.isConfigured {
                    stage = .searching
                    let sources = try await service.search(query, following: prior, keys: credentials)
                    try Task.checkCancellation()
                    foundSources = sources
                    stage = .summarizing
                    result = try await service.summarize(query, following: prior, sources: sources, keys: credentials)
                } else {
                    throw ResearchFailure.sampleUnavailable
                }
                try Task.checkCancellation()
                current = result
                context = nil
                question = ""
                if !result.isSample {
                    recent.insert(result, at: 0)
                    recent = Array(recent.prefix(20))
                    if let data = try? JSONEncoder().encode(recent) {
                        UserDefaults.standard.set(data, forKey: Self.historyKey)
                    }
                }
                cancel()
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription
                cancel()
            }
        }
    }
}

