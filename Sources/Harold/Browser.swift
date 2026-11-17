import SwiftUI
import WebKit

@MainActor
final class Browser: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published private(set) var url: URL?
    @Published private(set) var isLoading = false
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var error: String?

    let webView = WKWebView(frame: .zero)

    var bookmarkURL: URL? {
        guard let url, Self.isWebsite(url) else { return nil }
        return url
    }

    var bookmarkTitle: String? {
        url == webView.url ? webView.title : nil
    }
    private var observations: [NSKeyValueObservation] = []
    private var navigation: WKNavigation?
    private var pendingURL: URL?

    override init() {
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        observations = [
            webView.observe(\.url, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in self?.updateAddress() }
            },
            observe(\.canGoBack) { $0.canGoBack = $1 },
            observe(\.canGoForward) { $0.canGoForward = $1 },
            observe(\.isLoading) { $0.isLoading = $1 },
        ]
    }

    func open(_ destination: URL) -> Bool {
        guard Self.isWebsite(destination) else { return false }
        load(URLRequest(url: destination))
        return true
    }

    func goBack() {
        guard let item = webView.backForwardList.backItem else { return }
        begin(item.url) { webView.go(to: item) }
    }

    func goForward() {
        guard let item = webView.backForwardList.forwardItem else { return }
        begin(item.url) { webView.go(to: item) }
    }

    func reload() {
        if let url {
            if webView.url == url, error == nil {
                begin(url) { webView.reload() }
            } else {
                _ = open(url)
            }
        }
    }

    func stop() {
        webView.stopLoading()
        pendingURL = nil
        navigation = nil
        if let current = webView.url { url = current }
    }

    static func address(from input: String) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(where: \.isWhitespace) else { return nil }
        let explicit = hasScheme(text)
        guard let url = URL(string: explicit ? text : "https://" + text),
              isWebsite(url),
              let host = url.host,
              explicit || host.contains(".") || host.contains(":") || host.lowercased() == "localhost" else { return nil }
        return url
    }

    static func hasScheme(_ text: String) -> Bool {
        text.range(of: "^[a-zA-Z][a-zA-Z0-9+.-]*://", options: .regularExpression) != nil
    }

    private static func isWebsite(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty else { return false }
        return url.user == nil && url.password == nil
    }

    private func observe(
        _ property: KeyPath<WKWebView, Bool>,
        update: @escaping @MainActor @Sendable (Browser, Bool) -> Void
    ) -> NSKeyValueObservation {
        webView.observe(property, options: [.new]) { [weak self] _, change in
            guard let value = change.newValue else { return }
            Task { @MainActor in
                if let self { update(self, value) }
            }
        }
    }

    private func load(_ request: URLRequest) {
        guard let destination = request.url else { return }
        begin(destination) { webView.load(request) }
    }

    private func begin(_ destination: URL, perform: () -> WKNavigation?) {
        error = nil
        url = destination
        pendingURL = destination
        navigation = perform()
    }

    private func updateAddress() {
        guard pendingURL == nil, error == nil, let current = webView.url else { return }
        url = current
    }

    func webView(
        _ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let destination = action.request.url else {
            decisionHandler(.cancel)
            return
        }
        if Self.isWebsite(destination) || destination.absoluteString == "about:blank" {
            decisionHandler(.allow)
        } else if action.targetFrame?.isMainFrame == false,
                  let scheme = destination.scheme, ["about", "data", "blob"].contains(scheme) {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }

    func webView(
        _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
        for action: WKNavigationAction, windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if action.targetFrame == nil, let destination = action.request.url, Self.isWebsite(destination) {
            load(action.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation incoming: WKNavigation!) {
        if self.navigation !== incoming {
            navigation = incoming
            pendingURL = webView.url
        }
        error = nil
    }

    func webView(_ webView: WKWebView, didCommit incoming: WKNavigation!) {
        guard navigation === incoming else { return }
        pendingURL = nil
        updateAddress()
    }

    func webView(_ webView: WKWebView, didFinish incoming: WKNavigation!) {
        guard navigation === incoming else { return }
        pendingURL = nil
        updateAddress()
    }

    func webView(_ webView: WKWebView, didFail incoming: WKNavigation!, withError failure: Error) {
        showFailure(failure, for: incoming)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation incoming: WKNavigation!, withError failure: Error) {
        showFailure(failure, for: incoming)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        pendingURL = nil
        error = "Reload the page to continue."
    }

    private func showFailure(_ failure: Error, for incoming: WKNavigation?) {
        guard navigation === incoming else { return }
        pendingURL = nil
        if (failure as? URLError)?.code != .cancelled {
            error = failure.localizedDescription
        }
    }
}

private struct BrowserPage: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

struct BrowserView: View {
    @EnvironmentObject private var bookmarks: Bookmarks
    @ObservedObject var browser: Browser
    let onResearch: () -> Void
    let showingChat: Bool
    let onChat: () -> Void
    @State private var address = ""
    @State private var invalidAddress = false
    @FocusState private var addressFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onResearch) {
                    Label("Research", systemImage: "chevron.left")
                        .font(.harold(size: 13, weight: .bold))
                        .padding(.horizontal, 13)
                        .frame(height: 36)
                }
                .buttonStyle(HoverButtonStyle(fill: Palette.panel, radius: 18))
                .help("Return to research")

                control("Go back", icon: "arrow.left", disabled: !browser.canGoBack, action: browser.goBack)
                control("Go forward", icon: "arrow.right", disabled: !browser.canGoForward, action: browser.goForward)
                control(browser.isLoading ? "Stop loading" : "Reload",
                        icon: browser.isLoading ? "xmark" : "arrow.clockwise") {
                    if browser.isLoading { browser.stop() } else { browser.reload() }
                }

                HStack(spacing: 8) {
                    Image(systemName: browser.url?.scheme == "https" ? "lock" : "globe")
                        .foregroundStyle(Palette.muted)
                        .accessibilityHidden(true)
                    TextField("Website address", text: $address)
                        .font(.harold(size: 13, weight: .medium))
                        .textFieldStyle(.plain)
                        .focused($addressFocused)
                        .onSubmit { submit() }
                    if browser.isLoading {
                        ProgressView().controlSize(.small)
                    }
                }
                .padding(.horizontal, 13)
                .frame(height: 36)
                .modifier(Surface(border: addressFocused ? Palette.teal : Palette.border, radius: 18))

                if let url = browser.bookmarkURL {
                    let saved = bookmarks.contains(url)
                    control(saved ? "Remove bookmark" : "Bookmark this page", icon: saved ? "star.fill" : "star") {
                        bookmarks.toggle(url, title: browser.bookmarkTitle)
                    }
                }
                ChatToggle(isOpen: showingChat, onToggle: onChat)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Palette.raised)

            if invalidAddress {
                Text("Enter a valid website address.")
                    .font(.harold(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.amber)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Palette.peach)
            }

            ZStack {
                BrowserPage(webView: browser.webView)
                    .accessibilityHidden(browser.error != nil)
                if let failure = browser.error {
                    VStack(spacing: 13) {
                        Image(systemName: "globe")
                            .font(.system(size: 30, weight: .light))
                            .foregroundStyle(Palette.teal)
                        Text("Couldn’t load the page")
                            .font(.harold(size: 23, weight: .bold))
                        Text(failure)
                            .font(.harold(size: 14))
                            .foregroundStyle(Palette.secondary)
                            .multilineTextAlignment(.center)
                        Button("Try again", action: browser.reload)
                            .font(.harold(size: 13, weight: .bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .buttonStyle(HoverButtonStyle(fill: Palette.mint, radius: 17))
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.background)
                }
            }
        }
        .onAppear { address = browser.url?.absoluteString ?? "" }
        .onChange(of: browser.url) { _, url in
            if !addressFocused {
                address = url?.absoluteString ?? ""
                invalidAddress = false
            }
        }
        .onChange(of: address) { _, _ in invalidAddress = false }
        .background {
            Button("Focus website address") { addressFocused = true }
                .keyboardShortcut("l", modifiers: .command)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }

    private func submit() {
        guard let destination = Browser.address(from: address), browser.open(destination) else {
            invalidAddress = true
            return
        }
        address = destination.absoluteString
        addressFocused = false
    }

    private func control(_ title: String, icon: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(HoverButtonStyle(fill: Palette.panel, radius: 17))
        .disabled(disabled)
        .opacity(disabled ? 0.43 : 1)
        .accessibilityLabel(title)
        .help(title)
    }
}
