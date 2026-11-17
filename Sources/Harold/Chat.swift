import SwiftUI

struct ChatMessage: Identifiable {
    enum Role: String { case user, assistant }

    let id = UUID()
    let role: Role
    let text: String
}

@MainActor
final class Chat: ObservableObject {
    @Published var draft = ""
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isReplying = false
    @Published private(set) var error: String?
    private var task: Task<Void, Never>?

    func send(keys: ResearchKeys) {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isReplying, !keys.gemini.isEmpty else { return }
        draft = ""
        error = nil
        messages.append(ChatMessage(role: .user, text: text))
        respond(keys: keys)
    }

    func retry(keys: ResearchKeys) {
        guard !isReplying, !keys.gemini.isEmpty, messages.last?.role == .user else { return }
        respond(keys: keys)
    }

    func stop() {
        task?.cancel()
        task = nil
        isReplying = false
    }

    func clear() {
        stop()
        draft = ""
        messages = []
        error = nil
    }

    private func respond(keys: ResearchKeys) {
        error = nil
        isReplying = true
        let history = Array(messages.suffix(16))
        task = Task {
            do {
                let text = try await ResearchService().chatReply(history, keys: keys)
                try Task.checkCancellation()
                messages.append(ChatMessage(role: .assistant, text: text))
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription
            }
            isReplying = false
            task = nil
        }
    }
}

struct ChatSidebar: View {
    @ObservedObject var chat: Chat
    let keys: ResearchKeys
    let onClose: () -> Void
    let onSettings: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                HaroldMark(size: 25)
                Text("Chat").font(.harold(size: 18, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if !chat.messages.isEmpty {
                    icon("New chat", symbol: "square.and.pencil", action: chat.clear)
                }
                icon("Close chat", symbol: "xmark", action: onClose)
            }
            .padding(.horizontal, 13).frame(height: 56)
            Divider()

            ScrollViewReader { scroll in
                ScrollView {
                    VStack(spacing: 11) {
                        if chat.messages.isEmpty {
                            Text("Ask Harold anything")
                                .font(.harold(size: 16, weight: .bold))
                                .foregroundStyle(Palette.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 24)
                        }
                        ForEach(chat.messages) { message in
                            bubble(message)
                        }
                        if chat.isReplying {
                            ProgressView().controlSize(.small)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityLabel("Harold is replying")
                        }
                        Color.clear.frame(height: 1).id("chat-end").accessibilityHidden(true)
                    }
                    .padding(13)
                }
                .onAppear { scroll.scrollTo("chat-end", anchor: .bottom) }
                .onChange(of: chat.messages.count) { _, _ in
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        scroll.scrollTo("chat-end", anchor: .bottom)
                    }
                }
            }

            if let failure = chat.error {
                VStack(alignment: .leading, spacing: 6) {
                    Text(failure).font(.harold(size: 12)).foregroundStyle(Palette.amber)
                    Button("Retry") { chat.retry(keys: keys) }
                        .buttonStyle(.plain)
                        .font(.harold(size: 13, weight: .bold))
                        .foregroundStyle(Palette.teal)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.peach)
            }

            if keys.gemini.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Add a Gemini key to start chatting.")
                        .font(.harold(size: 13))
                    Button("Open Settings", action: onSettings)
                        .font(.harold(size: 13, weight: .bold))
                        .buttonStyle(.plain)
                        .foregroundStyle(Palette.teal)
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 5) {
                    TextField("Message Harold", text: $chat.draft)
                        .font(.harold(size: 14))
                        .textFieldStyle(.plain)
                        .onSubmit { chat.send(keys: keys) }
                        .onChange(of: chat.draft) { _, value in
                            if value.count > 2_000 { chat.draft = String(value.prefix(2_000)) }
                        }
                    if chat.isReplying {
                        icon("Stop reply", symbol: "stop.fill", action: chat.stop)
                    } else {
                        icon("Send message", symbol: "arrow.up") { chat.send(keys: keys) }
                            .disabled(chat.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.leading, 12).padding(.trailing, 5).padding(.vertical, 5)
                .modifier(Surface(radius: 20))
                .padding(11)
            }
        }
        .background(Palette.sidebar)
    }

    private func bubble(_ message: ChatMessage) -> some View {
        let fromUser = message.role == .user
        return Text(message.text)
            .font(.harold(size: 13, weight: .medium))
            .lineSpacing(3)
            .textSelection(.enabled)
            .padding(10)
            .modifier(Surface(fill: fromUser ? Palette.mint : Palette.panel, border: .clear, radius: 15))
            .frame(maxWidth: .infinity, alignment: fromUser ? .trailing : .leading)
            .accessibilityLabel((fromUser ? "You: " : "Harold: ") + message.text)
    }

    private func icon(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 29, height: 29)
        }
        .buttonStyle(HoverButtonStyle(fill: Palette.raised, radius: 15))
        .accessibilityLabel(title)
        .help(title)
    }
}

struct ChatToggle: View {
    let isOpen: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Label("Chat", systemImage: isOpen ? "bubble.left.fill" : "bubble.left")
                .font(.harold(size: 12, weight: .bold))
                .foregroundStyle(Palette.accent)
                .padding(.horizontal, 12)
                .frame(height: 32)
        }
        .buttonStyle(HoverButtonStyle(fill: isOpen ? Palette.mint : Palette.panel, radius: 16))
        .accessibilityLabel(isOpen ? "Hide chat" : "Show chat")
        .help(isOpen ? "Hide chat sidebar" : "Open chat sidebar")
    }
}
