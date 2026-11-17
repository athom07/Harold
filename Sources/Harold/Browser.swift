import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct BrowserHistoryEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    let url: URL
    let title: String
    let domain: String
    let visitedAt: Date
}

struct BrowserDownloadEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    let filename: String
    let sourceURL: URL
    let destinationPath: String
    var status: String
    let startedAt: Date
}

struct SavedBrowserSession: Codable {
    struct PageRecord: Codable {
        let id: UUID
        let url: URL
        let title: String
    }

    let pages: [PageRecord]
    let activePageID: UUID?
    let history: [BrowserHistoryEntry]
    let downloads: [BrowserDownloadEntry]
}

@MainActor
final class BrowserTab: NSObject, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    let id: UUID
    @Published private(set) var url: URL?
    @Published private(set) var title: String = "New Page"
    @Published private(set) var isLoading = false
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var error: String?
    @Published private(set) var isPDF = false
    @Published var pendingPermissionDomain: String?
    @Published var pendingPermissionType: String?

    let webView: WKWebView
    weak var owner: Browser?

    var verifiedDomain: String {
        guard let host = url?.host?.lowercased() else { return "Local Page" }
        return host.replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
    }

    private var observations: [NSKeyValueObservation] = []
    private var navigation: WKNavigation?
    private var pendingURL: URL?
    private var permissionDecisionHandler: ((WKPermissionDecision) -> Void)?

    init(id: UUID = UUID(), configuration: WKWebViewConfiguration? = nil, owner: Browser? = nil) {
        self.id = id
        self.owner = owner
        let config = configuration ?? Self.makeSharedConfiguration()
        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        observations = [
            webView.observe(\.url, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in self?.updateAddress() }
            },
            webView.observe(\.title, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in
                    guard let self else { return }
                    let nextTitle = self.webView.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !nextTitle.isEmpty {
                        self.title = nextTitle
                        self.owner?.saveSession()
                    }
                }
            },
            observe(\.canGoBack) { $0.canGoBack = $1 },
            observe(\.canGoForward) { $0.canGoForward = $1 },
            observe(\.isLoading) { $0.isLoading = $1 },
        ]
    }

    static func makeSharedConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        return config
    }

    func open(_ destination: URL) -> Bool {
        guard Browser.isWebsite(destination) else { return false }
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

    func resolvePermission(grant: Bool) {
        permissionDecisionHandler?(grant ? .grant : .deny)
        permissionDecisionHandler = nil
        pendingPermissionDomain = nil
        pendingPermissionType = nil
    }

    private func observe(
        _ property: KeyPath<WKWebView, Bool>,
        update: @escaping @MainActor @Sendable (BrowserTab, Bool) -> Void
    ) -> NSKeyValueObservation {
        webView.observe(property, options: [.new]) { [weak self] _, change in
            guard let value = change.newValue else { return }
            Task { @MainActor in
                if let self { update(self, value) }
            }
        }
    }

    func load(_ request: URLRequest) {
        guard let destination = request.url else { return }
        begin(destination) { webView.load(request) }
    }

    private func begin(_ destination: URL, perform: () -> WKNavigation?) {
        error = nil
        url = destination
        isPDF = destination.pathExtension.lowercased() == "pdf"
        if title == "New Page" {
            title = destination.host ?? destination.absoluteString
        }
        pendingURL = destination
        navigation = perform()
        owner?.saveSession()
    }

    private func updateAddress() {
        guard pendingURL == nil, error == nil, let current = webView.url else { return }
        url = current
        isPDF = current.pathExtension.lowercased() == "pdf"
        let currentTitle = webView.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !currentTitle.isEmpty {
            title = currentTitle
        } else if let host = current.host {
            title = host
        }
        owner?.recordHistory(url: current, title: title)
        owner?.saveSession()
    }

    func webView(
        _ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        guard let destination = action.request.url else {
            decisionHandler(.cancel, preferences)
            return
        }
        if action.shouldPerformDownload || destination.pathExtension.lowercased() == "zip" || destination.pathExtension.lowercased() == "dmg" || destination.pathExtension.lowercased() == "csv" {
            decisionHandler(.download, preferences)
            return
        }
        if Browser.isWebsite(destination) || destination.absoluteString == "about:blank" {
            decisionHandler(.allow, preferences)
        } else if action.targetFrame?.isMainFrame == false,
                  let scheme = destination.scheme, ["about", "data", "blob"].contains(scheme) {
            decisionHandler(.allow, preferences)
        } else {
            decisionHandler(.cancel, preferences)
        }
    }

    func webView(
        _ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if !response.canShowMIMEType {
            decisionHandler(.download)
            return
        }
        if let mime = response.response.mimeType?.lowercased(), mime == "application/pdf" {
            isPDF = true
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    func download(
        _ download: WKDownload, decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        let dest = downloadsDir.appendingPathComponent(suggestedFilename)
        owner?.recordDownload(
            filename: suggestedFilename,
            sourceURL: response.url ?? url ?? URL(string: "https://harold.local")!,
            destinationPath: dest.path,
            status: "Completed"
        )
        completionHandler(dest)
    }

    func webView(
        _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
        for action: WKNavigationAction, windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard let destination = action.request.url, Browser.isWebsite(destination) else { return nil }
        return owner?.openPopupOrNewTab(request: action.request, configuration: configuration)
    }

    func webViewDidClose(_ webView: WKWebView) {
        owner?.closeTab(id: id)
    }

    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = true
        panel.begin { result in
            completionHandler(result == .OK ? panel.urls : nil)
        }
    }

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        pendingPermissionDomain = origin.host.isEmpty ? verifiedDomain : origin.host
        switch type {
        case .camera: pendingPermissionType = "Camera"
        case .microphone: pendingPermissionType = "Microphone"
        case .cameraAndMicrophone: pendingPermissionType = "Camera & Microphone"
        @unknown default: pendingPermissionType = "Media Device"
        }
        permissionDecisionHandler = decisionHandler
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

@MainActor
final class Browser: ObservableObject {
    @Published private(set) var tabs: [BrowserTab] = []
    @Published var activeTabID: UUID? {
        didSet { saveSession() }
    }
    @Published private(set) var history: [BrowserHistoryEntry] = []
    @Published private(set) var downloads: [BrowserDownloadEntry] = []

    private static let sessionStorageKey = "harold.browser.session.v1"

    var activeTab: BrowserTab? {
        if let activeTabID, let found = tabs.first(where: { $0.id == activeTabID }) {
            return found
        }
        return tabs.first
    }

    var url: URL? { activeTab?.url }
    var isLoading: Bool { activeTab?.isLoading ?? false }
    var canGoBack: Bool { activeTab?.canGoBack ?? false }
    var canGoForward: Bool { activeTab?.canGoForward ?? false }
    var error: String? { activeTab?.error }
    var webView: WKWebView? { activeTab?.webView }

    var bookmarkURL: URL? {
        guard let url = activeTab?.url, Self.isWebsite(url) else { return nil }
        return url
    }

    var bookmarkTitle: String? {
        activeTab?.title
    }

    init() {
        restoreSession()
    }

    @discardableResult
    func open(_ destination: URL, inNewTab: Bool = false) -> Bool {
        guard Self.isWebsite(destination) else { return false }
        if inNewTab || tabs.isEmpty {
            let tab = BrowserTab(owner: self)
            tabs.append(tab)
            activeTabID = tab.id
            _ = tab.open(destination)
            saveSession()
            return true
        }
        guard let current = activeTab else { return false }
        let ok = current.open(destination)
        saveSession()
        return ok
    }

    func openSearchResults(for query: String, inNewTab: Bool = false) -> Bool {
        var components = URLComponents(string: "https://duckduckgo.com/")!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let searchURL = components.url else { return false }
        return open(searchURL, inNewTab: inNewTab)
    }

    func openPopupOrNewTab(request: URLRequest, configuration: WKWebViewConfiguration) -> WKWebView? {
        let popupTab = BrowserTab(configuration: configuration, owner: self)
        tabs.append(popupTab)
        activeTabID = popupTab.id
        popupTab.load(request)
        saveSession()
        return popupTab.webView
    }

    func selectTab(id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeTabID = id
    }

    func closeTab(id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        let wasActive = (activeTabID == id)
        tabs[idx].stop()
        tabs.remove(at: idx)
        if wasActive {
            activeTabID = tabs.last?.id
        }
        saveSession()
    }

    func goBack() { activeTab?.goBack() }
    func goForward() { activeTab?.goForward() }
    func reload() { activeTab?.reload() }
    func stop() { activeTab?.stop() }

    func recordHistory(url: URL, title: String) {
        guard Self.isWebsite(url) else { return }
        let domain = (url.host ?? "").replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
        history.removeAll { $0.url == url }
        history.insert(
            BrowserHistoryEntry(url: url, title: title.isEmpty ? domain : title, domain: domain, visitedAt: Date()),
            at: 0
        )
        history = Array(history.prefix(60))
    }

    func recordDownload(filename: String, sourceURL: URL, destinationPath: String, status: String) {
        downloads.insert(
            BrowserDownloadEntry(
                filename: filename,
                sourceURL: sourceURL,
                destinationPath: destinationPath,
                status: status,
                startedAt: Date()
            ),
            at: 0
        )
        downloads = Array(downloads.prefix(30))
        saveSession()
    }

    func clearHistory() {
        history.removeAll()
        saveSession()
    }

    func saveSession() {
        let pageRecords: [SavedBrowserSession.PageRecord] = tabs.compactMap { tab in
            guard let u = tab.url else { return nil }
            return SavedBrowserSession.PageRecord(id: tab.id, url: u, title: tab.title)
        }
        let session = SavedBrowserSession(
            pages: pageRecords,
            activePageID: activeTabID,
            history: history,
            downloads: downloads
        )
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: Self.sessionStorageKey)
        }
    }

    func restoreSession() {
        guard let data = UserDefaults.standard.data(forKey: Self.sessionStorageKey),
              let saved = try? JSONDecoder().decode(SavedBrowserSession.self, from: data) else {
            return
        }
        history = saved.history
        downloads = saved.downloads
        for record in saved.pages where Self.isWebsite(record.url) {
            let tab = BrowserTab(id: record.id, owner: self)
            tabs.append(tab)
            _ = tab.open(record.url)
        }
        if let activeID = saved.activePageID, tabs.contains(where: { $0.id == activeID }) {
            activeTabID = activeID
        } else {
            activeTabID = tabs.first?.id
        }
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

    static func isWebsite(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty else { return false }
        return url.user == nil && url.password == nil
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
    @State private var showingHistoryPopover = false
    @State private var showingDownloadsPopover = false
    @FocusState private var addressFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Compact Page Switcher Strip
            if !browser.tabs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(browser.tabs) { tab in
                            let isSelected = browser.activeTab?.id == tab.id
                            HStack(spacing: 6) {
                                Button {
                                    browser.selectTab(id: tab.id)
                                    address = tab.url?.absoluteString ?? ""
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: tab.url?.scheme == "https" ? "lock.fill" : "globe")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(isSelected ? Palette.accent : Palette.muted)
                                        Text(tab.verifiedDomain)
                                            .font(.harold(size: 11, weight: .bold))
                                            .foregroundStyle(Palette.accent)
                                        Text("·")
                                            .foregroundStyle(Palette.muted)
                                        Text(tab.title)
                                            .font(.harold(size: 12, weight: isSelected ? .bold : .medium))
                                            .lineLimit(1)
                                            .frame(maxWidth: 160, alignment: .leading)
                                    }
                                }
                                .buttonStyle(.plain)

                                Button {
                                    browser.closeTab(id: tab.id)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Palette.muted)
                                        .frame(width: 18, height: 18)
                                }
                                .buttonStyle(.plain)
                                .help("Close page")
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .background(isSelected ? Palette.mint : Palette.panel, in: Capsule())
                        }

                        Button {
                            _ = browser.open(URL(string: "https://duckduckgo.com")!, inNewTab: true)
                        } label: {
                            Label("New page", systemImage: "plus")
                                .labelStyle(.iconOnly)
                                .font(.system(size: 11, weight: .bold))
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(HoverButtonStyle(fill: Palette.panel, radius: 14))
                        .help("Open a new page")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
                .background(Palette.raised)
            }

            // Navigation & Verified Domain Bar
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

                // Clear Domain Badge + Address Input
                HStack(spacing: 8) {
                    if let activeTab = browser.activeTab {
                        HStack(spacing: 4) {
                            Image(systemName: activeTab.url?.scheme == "https" ? "lock.shield.fill" : "globe")
                                .foregroundStyle(Palette.teal)
                            Text(activeTab.verifiedDomain)
                                .font(.harold(size: 12, weight: .bold))
                                .foregroundStyle(Palette.accent)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Palette.mint.opacity(0.65), in: Capsule())
                        .help("Verified domain for sign-in and cookies")
                    }

                    TextField("Search the web or enter website address", text: $address)
                        .font(.harold(size: 13, weight: .medium))
                        .textFieldStyle(.plain)
                        .focused($addressFocused)
                        .onSubmit { submit() }
                    if browser.isLoading {
                        ProgressView().controlSize(.small)
                    }
                }
                .padding(.horizontal, 11)
                .frame(height: 36)
                .modifier(Surface(border: addressFocused ? Palette.teal : Palette.border, radius: 18))

                if let url = browser.bookmarkURL {
                    let saved = bookmarks.contains(url)
                    control(saved ? "Remove bookmark" : "Bookmark this page", icon: saved ? "star.fill" : "star") {
                        bookmarks.toggle(url, title: browser.bookmarkTitle)
                    }
                }

                control("Browsing history", icon: "clock.arrow.circlepath") {
                    showingHistoryPopover.toggle()
                }
                .popover(isPresented: $showingHistoryPopover) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Browsing History").font(.harold(size: 13, weight: .bold))
                            Spacer()
                            if !browser.history.isEmpty {
                                Button("Clear") { browser.clearHistory() }
                                    .font(.harold(size: 11))
                            }
                        }
                        if browser.history.isEmpty {
                            Text("No pages visited yet.")
                                .font(.harold(size: 12))
                                .foregroundStyle(Palette.muted)
                        } else {
                            ForEach(browser.history.prefix(12)) { item in
                                Button {
                                    _ = browser.open(item.url)
                                    showingHistoryPopover = false
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title).font(.harold(size: 12, weight: .semibold)).lineLimit(1)
                                        Text(item.domain).font(.harold(size: 11)).foregroundStyle(Palette.muted)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(12)
                    .frame(width: 280)
                }

                control("Downloads", icon: "arrow.down.circle") {
                    showingDownloadsPopover.toggle()
                }
                .popover(isPresented: $showingDownloadsPopover) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Downloads").font(.harold(size: 13, weight: .bold))
                        if browser.downloads.isEmpty {
                            Text("No files downloaded in this session.")
                                .font(.harold(size: 12))
                                .foregroundStyle(Palette.muted)
                        } else {
                            ForEach(browser.downloads.prefix(10)) { dl in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dl.filename).font(.harold(size: 12, weight: .semibold)).lineLimit(1)
                                    Text("\(dl.status) · \(dl.destinationPath)")
                                        .font(.harold(size: 10))
                                        .foregroundStyle(Palette.muted)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .frame(width: 280)
                }

                ChatToggle(isOpen: showingChat, onToggle: onChat)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Palette.raised)

            // Site Permission Prompt Banner
            if let activeTab = browser.activeTab,
               let permDomain = activeTab.pendingPermissionDomain,
               let permType = activeTab.pendingPermissionType {
                HStack(spacing: 10) {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundStyle(Palette.accent)
                    Text("\(permDomain) requests access to your \(permType).")
                        .font(.harold(size: 12, weight: .semibold))
                    Spacer()
                    Button("Deny") { activeTab.resolvePermission(grant: false) }
                        .font(.harold(size: 12, weight: .semibold))
                    Button("Allow") { activeTab.resolvePermission(grant: true) }
                        .font(.harold(size: 12, weight: .bold))
                        .foregroundStyle(Palette.accent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Palette.mint)
            }

            if invalidAddress {
                Text("Enter a valid website address or search query.")
                    .font(.harold(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.amber)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Palette.peach)
            }

            ZStack {
                if let activeWebView = browser.webView {
                    BrowserPage(webView: activeWebView)
                        .id(browser.activeTab?.id)
                        .accessibilityHidden(browser.error != nil)
                }
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
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            invalidAddress = true
            return
        }
        if let destination = Browser.address(from: trimmed), browser.open(destination) {
            address = destination.absoluteString
            addressFocused = false
        } else if !Browser.hasScheme(trimmed), browser.openSearchResults(for: trimmed) {
            address = browser.url?.absoluteString ?? trimmed
            addressFocused = false
        } else {
            invalidAddress = true
        }
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
