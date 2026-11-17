import WebKit

@MainActor
final class ResearchPage: NSObject, WKNavigationDelegate {
    private let view: WKWebView
    private var waiting: CheckedContinuation<Void, Error>?
    private var timeout: Task<Void, Never>?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        view = WKWebView(frame: CGRect(x: 0, y: 0, width: 1200, height: 900), configuration: configuration)
        super.init()
        view.navigationDelegate = self
    }

    func load(_ url: URL) async throws {
        try Task.checkCancellation()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiting = continuation
                timeout = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(25)) } catch { return }
                    self?.finish(.failure(URLError(.timedOut)))
                    self?.view.stopLoading()
                }
                view.load(URLRequest(url: url))
            }
        } onCancel: {
            Task { @MainActor in
                self.finish(.failure(CancellationError()))
                self.view.stopLoading()
            }
        }
        try Task.checkCancellation()
    }

    func search(_ query: String) async throws -> [URL] {
        if let primary = try? await search(query, usingDuckDuckGo: false), !primary.isEmpty {
            return primary
        }
        try Task.checkCancellation()
        return try await search(query, usingDuckDuckGo: true)
    }

    private func search(_ query: String, usingDuckDuckGo: Bool) async throws -> [URL] {
        let endpoint = usingDuckDuckGo ? "https://html.duckduckgo.com/html/" : "https://www.google.com/search"
        var url = URLComponents(string: endpoint)!
        url.queryItems = [.init(name: "q", value: query)]
        try await load(url.url!)
        let script = """
        Array.from(document.querySelectorAll('a.result__a, a:has(h3)')).map(a => {
          const u = new URL(a.href, location.href);
          if (u.hostname.endsWith('.duckduckgo.com') && u.pathname === '/l/') {
            return u.searchParams.get('uddg');
          }
          if (u.hostname === 'www.google.com' && u.pathname === '/url') {
            return u.searchParams.get('q') || u.searchParams.get('url');
          }
          return u.href;
        }).filter(Boolean)
        """
        let links = try await view.evaluateJavaScript(script) as? [String] ?? []
        var seen = Set<URL>()
        return links.compactMap { URL(string: $0) }.filter {
            guard let scheme = $0.scheme, ["https", "http"].contains(scheme),
                  let host = $0.host, host != "www.google.com", host != "html.duckduckgo.com", host != "duckduckgo.com",
                  $0.user == nil, $0.password == nil else { return false }
            return seen.insert($0).inserted
        }.prefix(5).map { $0 }
    }

    func article(_ url: URL, id: Int) async throws -> Source {
        try await load(url)
        guard let resource = Bundle.module.url(forResource: "Readability", withExtension: "js") else {
            throw ResearchFailure.invalidBrief
        }
        let readability = try String(contentsOf: resource, encoding: .utf8)
        let script = readability + """
        ;(() => {
          const rawBytes = document.documentElement ? document.documentElement.outerHTML.length : 0;
          const article = new Readability(document.cloneNode(true)).parse();
          if (!article) return null;
          const words = article.textContent.trim().split(/\\s+/).slice(0, 1500);
          return {title: article.title || document.title,
                  text: words.join(' '),
                  wordCount: String(words.length),
                  rawBytes: String(rawBytes),
                  url: location.href};
        })();
        """
        guard let result = try await view.evaluateJavaScript(script) as? [String: String],
              let text = result["text"], text.count > 150,
              let finalURL = URL(string: result["url"] ?? ""), ["http", "https"].contains(finalURL.scheme ?? "") else {
            throw ResearchFailure.noSources
        }
        let rawBytes = Int(result["rawBytes"] ?? "0") ?? 0
        let wordCount = Int(result["wordCount"] ?? "0") ?? text.split(whereSeparator: \.isWhitespace).count
        return Source(
            id: id,
            title: result["title"] ?? url.host ?? "Source",
            url: finalURL,
            excerpt: text,
            rawByteCount: rawBytes,
            distilledWordCount: wordCount
        )
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finish(.success(())) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { finish(.failure(URLError(.networkConnectionLost))) }

    private func finish(_ result: Result<Void, Error>) {
        let continuation = waiting
        waiting = nil
        timeout?.cancel()
        timeout = nil
        continuation?.resume(with: result)
    }
}

@available(macOS 26.0, *)
@MainActor
struct LocalResearch {
    func run(
        question: String,
        prior: Brief?,
        stageChanged: @escaping (ResearchStage) -> Void,
        sourcesChanged: @escaping ([Source]) -> Void,
        cardsChanged: @escaping ([ResearchCard]) -> Void
    ) async throws -> Brief {
        let model: any ResearchLanguageModel = AppleResearchModel()

        // Stage 1: Intent & Query Dispatch
        stageChanged(.intentDispatch)
        let generated = (try? await model.searchQueries(for: question, prior: prior)) ?? []
        try Task.checkCancellation()
        let queries = generated.isEmpty ? [String(question.prefix(300))] : generated

        // Stage 2: Headless Search Resolution via local WKWebView
        stageChanged(.headlessSearch(queries))
        var urls: [URL] = []
        for query in queries {
            let results = (try? await ResearchPage().search(query)) ?? []
            try Task.checkCancellation()
            for url in results where !urls.contains(url) { urls.append(url) }
        }
        guard !urls.isEmpty else { throw ResearchFailure.noSources }
        let targets = Array(urls.prefix(5))

        // Stage 3 & 4: Staggered Background Fetching (3 workers, 400ms stagger) + Readability.js DOM Distillation
        stageChanged(.backgroundFetching(loaded: 0, total: targets.count))
        var sources: [Source] = []
        for start in stride(from: 0, to: targets.count, by: 3) {
            try await withThrowingTaskGroup(of: Source?.self) { group in
                for index in start..<min(start + 3, targets.count) {
                    let destination = targets[index]
                    group.addTask { @MainActor in
                        try await Task.sleep(for: .milliseconds((index - start) * 400))
                        do {
                            return try await ResearchPage().article(destination, id: index + 1)
                        } catch {
                            try Task.checkCancellation()
                            return nil
                        }
                    }
                }
                for try await source in group {
                    if let source {
                        sources.append(source)
                        sources.sort { $0.id < $1.id }
                        sourcesChanged(sources)
                        stageChanged(.backgroundFetching(loaded: sources.count, total: targets.count))
                    }
                }
            }
        }
        if sources.isEmpty {
            // Dependable search fallback: preserve raw organic URLs even if Readability.js extraction failed
            sources = targets.enumerated().map { idx, targetURL in
                Source(
                    id: idx + 1,
                    title: targetURL.host ?? targetURL.absoluteString,
                    url: targetURL,
                    excerpt: "Article extraction was unavailable for \(targetURL.host ?? "this page"). Open the original page directly in Harold's browser."
                )
            }
            sourcesChanged(sources)
        }
        stageChanged(.domDistillation(sources: sources.count))

        // Stage 5: Two-Stage Map-Reduce Synthesis
        var facts: [SourcedFacts] = []
        for (idx, source) in sources.enumerated() {
            try Task.checkCancellation()
            stageChanged(.mapReduceSynthesis(mapped: idx, total: sources.count))
            guard let fact = try? await model.facts(for: source, question: question) else { continue }
            if !fact.text.isEmpty {
                var enriched = source
                enriched.mappedClaims = fact.claims
                enriched.mappedAdvantages = fact.advantages
                enriched.mappedDisadvantages = fact.disadvantages
                if let replaceIndex = sources.firstIndex(where: { $0.id == source.id }) {
                    sources[replaceIndex] = enriched
                    sourcesChanged(sources)
                }
                facts.append(SourcedFacts(
                    source: enriched,
                    claims: fact.claims,
                    advantages: fact.advantages,
                    disadvantages: fact.disadvantages,
                    text: fact.text
                ))
            }
        }
        try Task.checkCancellation()
        stageChanged(.mapReduceSynthesis(mapped: facts.count, total: sources.count))
        let generatedCards: [ResearchCard]?
        if facts.isEmpty {
            generatedCards = nil
        } else {
            generatedCards = try? await model.assemble(question: question, prior: prior, facts: facts, update: cardsChanged)
        }
        try Task.checkCancellation()
        let cards = generatedCards ?? [
            ResearchCard(kind: .summary, title: "Summary unavailable",
                         text: "The on-device model couldn’t complete a summary. Open the original sources below."),
            ResearchCard(kind: .sources, title: "Original sources")
        ]
        return Brief(
            query: question,
            generatedQueries: queries,
            cards: cards,
            sources: sources.map { source in
                var clean = source
                clean = Source(
                    id: clean.id,
                    title: clean.title,
                    url: clean.url,
                    excerpt: clean.excerpt,
                    rawByteCount: clean.rawByteCount,
                    distilledWordCount: clean.distilledWordCount,
                    mappedClaims: clean.mappedClaims,
                    mappedAdvantages: clean.mappedAdvantages,
                    mappedDisadvantages: clean.mappedDisadvantages
                )
                return clean
            },
            isSample: false,
            engineLabel: model.displayName
        )
    }
}

