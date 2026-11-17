import SwiftUI

@main
@MainActor
struct HaroldApp: App {
    @StateObject private var account = Account()
    @StateObject private var bookmarks = Bookmarks()

    var body: some Scene {
        WindowGroup {
            WorkspaceView()
                .preferredColorScheme(.light)
                .environmentObject(account)
                .environmentObject(bookmarks)
                .onAppear { Task { await account.restore() } }
        }
        .defaultSize(width: 1_260, height: 840)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
    }
}

struct WorkspaceView: View {
    @EnvironmentObject private var account: Account
    @EnvironmentObject private var bookmarks: Bookmarks
    @StateObject private var chat = Chat()
    @State private var showingChat = false
    @State private var showingAccount = false
    @StateObject private var workspace = Workspace()
    @StateObject private var voice = Voice()
    @StateObject private var browser = Browser()
    @State private var showingBrowser = false
    @State private var invalidWebsite = false
    @State private var showingSettings = false
    @FocusState private var questionFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 215)
                .background(.regularMaterial)
            Rectangle().fill(Palette.border).frame(width: 1)
            VStack(spacing: 0) {
                ZStack {
                    VStack(spacing: 0) {
                        topBar
                        workspaceContent
                    }
                    .opacity(showingBrowser ? 0 : 1)
                    .accessibilityHidden(showingBrowser)
                    .allowsHitTesting(!showingBrowser)
                    if showingBrowser {
                        BrowserView(
                            browser: browser, onResearch: { showingBrowser = false },
                            showingChat: showingChat, onChat: { showingChat.toggle() }
                        )
                    }
                }
            }
            .background(Palette.background)
            if showingChat {
                Rectangle().fill(Palette.border).frame(width: 1)
                ChatSidebar(
                    chat: chat, keys: workspace.keys, onClose: { showingChat = false },
                    onSettings: { showingSettings = true }
                )
                .frame(width: 302)
            }
        }
        .frame(minWidth: showingChat ? 1_050 : 760, minHeight: 580)
        .foregroundStyle(Palette.text)
        .tint(Palette.accent)
        .sheet(isPresented: $showingSettings) {
            KeySettings(keys: workspace.keys, onSave: workspace.saveKeys)
                .environment(\.openURL, OpenURLAction { url in
                    guard openWebsite(url) else { return .discarded }
                    showingSettings = false
                    return .handled
                })
        }
        .sheet(isPresented: $showingAccount) {
            AccountView()
                .environment(\.openURL, OpenURLAction { url in
                    guard openWebsite(url) else { return .discarded }
                    showingAccount = false
                    return .handled
                })
        }
        .environment(\.openURL, OpenURLAction { openWebsite($0) ? .handled : .discarded })
        .onChange(of: workspace.current?.id) { _, _ in voice.stopSpeech() }
        .onChange(of: workspace.stage) { _, stage in
            if stage != nil {
                voice.stopListening()
                voice.stopSpeech()
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                HaroldMark(size: 34)
                Text("Harold")
                    .font(.harold(size: 23, weight: .bold))
                    .tracking(-0.65)
            }
            .padding(.top, 48)
            .padding(.bottom, 25)

            Button {
                voice.stopListening()
                workspace.newResearch()
                showingBrowser = false
                invalidWebsite = false
                questionFocused = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                    Text("New research").font(.harold(size: 13, weight: .bold))
                    Spacer()
                    Text("⇧⌘N").font(.harold(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 11).frame(height: 38)
            }
            .foregroundStyle(.white)
            .buttonStyle(HoverButtonStyle(fill: Palette.accent, hover: .white.opacity(0.13), radius: 19))
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .help("Start new research (Shift-Command-N)")

            if browser.url != nil {
                Button {
                    showingBrowser = true
                    questionFocused = false
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "globe").frame(width: 20)
                        Text("Browser")
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 8, weight: .semibold))
                    }
                    .font(.harold(size: 13, weight: .bold))
                    .padding(.horizontal, 9)
                    .frame(height: 34)
                }
                .buttonStyle(HoverButtonStyle(fill: showingBrowser ? Palette.mint : .clear, radius: 17))
                .padding(.top, 8)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if !workspace.recent.isEmpty {
                        SmallLabel(text: "Recent")
                            .padding(.horizontal, 7).padding(.bottom, 4)
                        ForEach(workspace.recent) { brief in
                            sidebarItem(brief.query, icon: "clock", brief: brief)
                        }
                        Spacer().frame(height: 12)
                    }
                    SmallLabel(text: "Sample briefs")
                        .padding(.horizontal, 7).padding(.bottom, 4)
                    ForEach(Samples.examples) { sample in
                        sidebarItem(sample.shortcut, icon: sample.icon, brief: sample.brief)
                    }

                    SmallLabel(text: "Bookmarks")
                        .padding(.horizontal, 7).padding(.top, 17).padding(.bottom, 4)
                    if bookmarks.entries.isEmpty {
                        Text("Star a page to save it here.")
                            .font(.harold(size: 12))
                            .foregroundStyle(Palette.muted)
                            .padding(.horizontal, 7)
                    } else {
                        ForEach(bookmarks.entries) { bookmark in
                            bookmarkRow(bookmark)
                        }
                    }
                }
            }
            .contentMargins(.vertical, 0)
            .padding(.top, 27)

            Spacer(minLength: 12)
            Divider().overlay(Palette.border)
            Button {
                showingAccount = true
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 15)).foregroundStyle(Palette.teal).frame(width: 20)
                    Text(account.user == nil ? "Account" : account.user?.email ?? "Account")
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 8, weight: .semibold))
                }
                .font(.harold(size: 13, weight: .bold))
                .padding(.horizontal, 7).frame(height: 35)
            }
            .buttonStyle(HoverButtonStyle())
            .help("Sign in or manage your account")
            .padding(.top, 7)

            Button {
                showingSettings = true
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14)).foregroundStyle(Palette.muted)
                        .frame(width: 20)
                    Text("Settings").font(.harold(size: 13, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 8, weight: .semibold)).foregroundStyle(Palette.muted)
                }
                .padding(.horizontal, 7).frame(height: 35)
            }
            .buttonStyle(HoverButtonStyle())
            .keyboardShortcut(",", modifiers: .command)
            .padding(.bottom, 13)
        }
        .padding(.horizontal, 15)
    }

    private func sidebarItem(_ label: String, icon: String, brief: Brief) -> some View {
        let selected = !showingBrowser && workspace.current?.id == brief.id && workspace.stage == nil
        return Button {
            voice.stopListening()
            workspace.open(brief)
            showingBrowser = false
            invalidWebsite = false
        } label: {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.harold(size: 13, weight: .semibold))
                    .foregroundStyle(selected ? Palette.accent : Palette.muted)
                    .frame(width: 20)
                Text(label)
                    .font(.harold(size: 13, weight: selected ? .bold : .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(selected ? Palette.text : Palette.secondary)
            .padding(.horizontal, 7)
            .frame(height: 34)
        }
        .buttonStyle(HoverButtonStyle(
            fill: selected ? Palette.mint : .clear, radius: 17
        ))
        .help(brief.query)
    }

    private func bookmarkRow(_ bookmark: Bookmark) -> some View {
        Button {
            _ = openWebsite(bookmark.url)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "bookmark")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.teal)
                    .frame(width: 20)
                Text(bookmark.title)
                    .font(.harold(size: 13, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 7)
            .frame(height: 34)
        }
        .buttonStyle(HoverButtonStyle(radius: 17))
        .help(bookmark.url.absoluteString)
        .contextMenu {
            Button("Remove Bookmark") { bookmarks.remove(bookmark.url) }
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.2x2")
                    .font(.harold(size: 13, weight: .semibold)).foregroundStyle(Palette.accent)
                Text("Research workspace")
                    .font(.harold(size: 13, weight: .semibold))
            }
            Spacer()
            Button {
                showingSettings = true
            } label: {
                HStack(spacing: 6) {
                    Circle().fill(workspace.canResearch ? Palette.teal : Palette.amber).frame(width: 6, height: 6)
                    Text(workspace.canResearch ? "On-device research" : "Setup needed")
                        .font(.harold(size: 12, weight: .bold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .semibold)).foregroundStyle(Palette.muted)
                }
                .padding(.horizontal, 9).frame(height: 26)
            }
            .buttonStyle(HoverButtonStyle(fill: Palette.raised, radius: 13))
            .help("Configure live research")
            ChatToggle(isOpen: showingChat) { showingChat.toggle() }
        }
        .padding(.horizontal, 24)
        .frame(height: 49)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.border).frame(height: 1) }
    }

    private var workspaceContent: some View {
        GeometryReader { geometry in
            let width = max(300, min(920, geometry.size.width - 58))
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(spacing: 26) {
                        hero
                            .frame(width: width)
                        if let stage = workspace.stage {
                            progress(stage, width: width)
                        } else if let brief = workspace.current {
                            BriefView(
                                brief: brief,
                                width: width,
                                isSpeaking: voice.speaking,
                                onSpeak: { voice.toggleSpeech(brief.summary) },
                                onFollowUp: {
                                    workspace.followUp(on: brief)
                                    jump(in: scroll, to: "composer", anchor: .top)
                                    questionFocused = true
                                },
                                onSources: { jump(in: scroll, to: ResearchCard.Kind.sources, anchor: .center) },
                                canFollowUp: workspace.canResearch
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 32)
                    .background(alignment: .top) { WorkspaceBackdrop() }
                }
                .onChange(of: workspace.current?.id) { _, _ in
                    jump(in: scroll, to: "composer", anchor: .top)
                }
            }
        }
    }

    private func jump(in scroll: ScrollViewProxy, to target: some Hashable, anchor: UnitPoint) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
            scroll.scrollTo(target, anchor: anchor)
        }
    }

    private var hero: some View {
        VStack(spacing: 18) {
            VStack(spacing: 13) {
                HaroldMark(size: 60, prominent: true)
                Text("Where to?")
                    .font(.harold(size: 52, weight: .heavy))
                    .tracking(-2.0)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.top, 38)
            .padding(.bottom, 3)
            .id("composer")

            VStack(alignment: .leading, spacing: 10) {
                if let context = workspace.context {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.turn.up.left").foregroundStyle(Palette.accent)
                        Text("Following up on \(context.query)").lineLimit(1)
                        Spacer()
                        Button("Remove context", systemImage: "xmark") { workspace.clearContext() }
                            .labelStyle(.iconOnly)
                            .buttonStyle(HoverButtonStyle())
                    }
                    .font(.harold(size: 12)).foregroundStyle(Palette.secondary)
                    .padding(.horizontal, 11).padding(.top, 8)
                }

                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Palette.accent)
                        .padding(.leading, 8)
                        .accessibilityHidden(true)
                    TextField(
                        "Question or website", text: $workspace.question,
                        prompt: Text(voice.listening ? "Listening…" : "Search or enter a website").foregroundStyle(Palette.muted)
                    )
                    .font(.harold(size: 16, weight: .medium))
                    .textFieldStyle(.plain)
                    .focused($questionFocused)
                    .disabled(workspace.stage != nil)
                    .onSubmit { submit() }
                    .onChange(of: workspace.question) { _, replacement in
                        invalidWebsite = false
                        if replacement.count > 700 { workspace.question = String(replacement.prefix(700)) }
                    }

                    Button {
                        voice.toggleListening { workspace.question = $0 }
                    } label: {
                        Image(systemName: voice.listening ? "stop.fill" : "mic")
                            .font(.harold(size: 14, weight: .medium))
                            .foregroundStyle(voice.listening ? Palette.accent : Palette.secondary)
                            .frame(width: 35, height: 35)
                    }
                    .accessibilityLabel(voice.listening ? "Stop dictation" : "Dictate a question")
                    .help(voice.listening ? "Stop dictation" : "Dictate a question")
                    .disabled(workspace.stage != nil || voice.preparing)
                    .buttonStyle(HoverButtonStyle(
                        fill: Palette.raised, radius: 17.5
                    ))

                    Button {
                        if workspace.stage == nil { submit() } else { workspace.cancel() }
                    } label: {
                        Image(systemName: workspace.stage == nil ? "arrow.right" : "stop.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 35, height: 35)
                    }
                    .accessibilityLabel(workspace.stage == nil ? "Go" : "Cancel research")
                    .help(workspace.stage == nil ? "Go" : "Cancel research")
                    .opacity(workspace.stage == nil && workspace.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.57 : 1)
                    .buttonStyle(HoverButtonStyle(fill: Palette.accent, hover: .white.opacity(0.14), radius: 17.5))
                }
                .padding(8)
            }
            .modifier(Surface(
                border: questionFocused ? Palette.teal : .white, radius: workspace.context == nil ? 26 : 20
            ))
            .shadow(color: Palette.accent.opacity(0.10), radius: 18, y: 8)
            .frame(maxWidth: 647)

            if let message = invalidWebsite ? "Enter a valid HTTP or HTTPS address." : voice.error ?? workspace.error {
                Label(message, systemImage: "exclamationmark.circle")
                    .font(.harold(size: 13))
                    .foregroundStyle(Palette.amber)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .modifier(Surface(fill: Palette.peach, border: .clear, radius: 12))
                    .accessibilityAddTraits(.updatesFrequently)
            }

            HStack(spacing: 7) {
                ForEach(Samples.examples) { sample in
                    Button {
                        voice.error = nil
                        workspace.open(sample.brief)
                    } label: {
                        Label(sample.shortcut, systemImage: sample.icon)
                            .font(.harold(size: 12, weight: .bold))
                            .foregroundStyle(Palette.secondary)
                            .padding(.horizontal, 10).frame(height: 29)
                    }
                    .buttonStyle(HoverButtonStyle(fill: Palette.raised, radius: 15))
                    .disabled(workspace.stage != nil)
                    .help(sample.brief.query)
                }
            }
            .padding(.bottom, 2)
        }
    }

    private func submit() {
        voice.error = nil
        let text = workspace.question.trimmingCharacters(in: .whitespacesAndNewlines)
        if let destination = Browser.address(from: text), openWebsite(destination) {
            workspace.question = ""
        } else if Browser.hasScheme(text) {
            invalidWebsite = true
        } else {
            workspace.submit()
        }
    }

    private func openWebsite(_ url: URL) -> Bool {
        guard browser.open(url) else { return false }
        voice.stopListening()
        questionFocused = false
        showingBrowser = true
        return true
    }

    private func progress(_ stage: ResearchStage, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Divider().overlay(Palette.border.opacity(0.55))
            Text(workspace.pendingQuestion).font(.harold(size: 25, weight: .bold))
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(stage.title).font(.harold(size: 14, weight: .medium))
                    Spacer()
                }
                ForEach(workspace.foundSources) { source in SourceRow(source: source) }
                if !workspace.foundSources.isEmpty {
                    Text("Reading and synthesizing on this Mac")
                        .font(.harold(size: 12))
                        .foregroundStyle(Palette.muted)
                }
            }
            .padding(16)
            .modifier(Surface())
            .accessibilityAddTraits(.updatesFrequently)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 290))], spacing: 14) {
                ForEach(workspace.streamingCards) { card in
                    CardView(card: card, sources: workspace.foundSources)
                }
                if workspace.streamingCards.isEmpty {
                    ForEach(0..<2) { _ in
                        VStack(alignment: .leading, spacing: 14) {
                            RoundedRectangle(cornerRadius: 5).fill(Palette.mint).frame(width: 110, height: 17)
                            ForEach(0..<3) { _ in
                                RoundedRectangle(cornerRadius: 4).fill(Palette.raised).frame(height: 12)
                            }
                        }
                        .padding(22)
                        .modifier(Surface())
                        .accessibilityHidden(true)
                    }
                }
            }
        }
        .frame(width: width)
    }
}

private struct KeySettings: View {
    @Environment(\.dismiss) private var dismiss
    @State var keys: ResearchKeys
    let onSave: (ResearchKeys) throws -> Void
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                HaroldMark(size: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Research settings").font(.harold(size: 22, weight: .bold))
                    Text("Connect providers to research your own questions.")
                        .font(.harold(size: 13)).foregroundStyle(Palette.secondary)
                }
            }
            Divider()
            field("Tavily API key", value: $keys.tavily, link: URL(string: "https://app.tavily.com/")!)
            field("Gemini API key", value: $keys.gemini, link: URL(string: "https://aistudio.google.com/apikey")!)
            Text("Add Gemini for chat, or both keys for live research. Harold saves your keys in macOS Keychain.")
                .font(.harold(size: 13))
                .foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let error { Text(error).foregroundStyle(Palette.amber) }

            HStack {
                if !keys.tavily.isEmpty || !keys.gemini.isEmpty {
                    Button("Clear fields") { keys = ResearchKeys() }
                        .help("Save the cleared fields to return to demo mode")
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save Settings") { save() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(23)
        .frame(width: 452)
        .foregroundStyle(Palette.text)
        .background(Palette.background)
    }

    private func field(_ name: String, value: Binding<String>, link: URL) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).font(.harold(size: 13, weight: .bold))
                Spacer()
                Link("Get a key", destination: link).font(.harold(size: 12)).foregroundStyle(Palette.accent)
            }
            SecureField(name, text: value)
                .textFieldStyle(.plain)
                .font(.harold(size: 14))
                .padding(10)
                .modifier(Surface(radius: 12))
        }
    }

    private func save() {
        let tavily = keys.tavily.trimmingCharacters(in: .whitespacesAndNewlines)
        let gemini = keys.gemini.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tavily.contains(where: \.isWhitespace), !gemini.contains(where: \.isWhitespace) else {
            error = "API keys can’t contain whitespace."
            return
        }
        do {
            try onSave(ResearchKeys(tavily: tavily, gemini: gemini))
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
