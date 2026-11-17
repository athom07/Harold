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
        var url = URLComponents(string: "https://www.google.com/search")!
        url.queryItems = [.init(name: "q", value: query)]
        try await load(url.url!)
        let script = """
        Array.from(document.querySelectorAll('a')).filter(a => a.querySelector('h3')).map(a => {
          let u = new URL(a.href, location.href);
          if (u.pathname === '/url') return u.searchParams.get('q') || u.searchParams.get('url');
          return u.href;
        }).filter(Boolean)
        """
        let links = try await view.evaluateJavaScript(script) as? [String] ?? []
        var seen = Set<URL>()
        return links.compactMap { URL(string: $0) }.filter {
            guard let scheme = $0.scheme, ["https", "http"].contains(scheme),
                  let host = $0.host, !host.hasSuffix("google.com"),
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
          const article = new Readability(document.cloneNode(true)).parse();
          if (!article) return null;
          return {title: article.title || document.title,
                  text: article.textContent.split(/\\s+/).slice(0, 1500).join(' '),
                  url: location.href};
        })();
        """
        guard let result = try await view.evaluateJavaScript(script) as? [String: String],
              let text = result["text"], text.count > 150,
              let finalURL = URL(string: result["url"] ?? ""), ["http", "https"].contains(finalURL.scheme ?? "") else {
            throw ResearchFailure.noSources
        }
        return Source(id: id, title: result["title"] ?? url.host ?? "Source", url: finalURL, excerpt: text)
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
        question: String, prior: Brief?,
        sourcesChanged: @escaping ([Source]) -> Void,
        cardsChanged: @escaping ([ResearchCard]) -> Void
    ) async throws -> Brief {
        let model: any ResearchLanguageModel = AppleResearchModel()
        let queries = try await model.searchQueries(for: question, prior: prior)
        var urls: [URL] = []
        for query in queries {
            let results = try await ResearchPage().search(query)
            for url in results where !urls.contains(url) { urls.append(url) }
        }
        guard !urls.isEmpty else { throw ResearchFailure.noSources }
        let targets = Array(urls.prefix(5))
        var sources: [Source] = []
        // Three workers at a time, with staggered starts. Each view uses Harold's cookie store.
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
                    }
                }
            }
        }
        guard !sources.isEmpty else { throw ResearchFailure.noSources }
        var facts: [SourcedFacts] = []
        for source in sources {
            try Task.checkCancellation()
            let fact = try await model.facts(for: source, question: question)
            if !fact.text.isEmpty { facts.append(fact) }
        }
        guard !facts.isEmpty else { throw ResearchFailure.noSources }
        let cards = try await model.assemble(question: question, facts: facts, update: cardsChanged)
        return Brief(query: question, cards: cards, sources: facts.map {
            Source(id: $0.source.id, title: $0.source.title, url: $0.source.url, excerpt: "")
        }, isSample: false)
    }
}
