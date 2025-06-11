//
//  ContentView.swift
//  Genius
//
//  Created by Shadman Ahmed on 6/10/25.
//

import SwiftUI
import Combine
import FoundationModels

// MARK: – ViewModel

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false

    private let session: LanguageModelSession
    private let model = SystemLanguageModel.default

    init() {
        session = LanguageModelSession(
            model: model,
            instructions: "You are a helpful AI assistant that give nice short answers in a super friendly way. Type anything you would like to know and I will do my best to help!"
        )
    }

    func send(_ text: String) async {
        guard !text.isEmpty else { return }

        // Check model availability
        switch model.availability {
        case .available: break
        case .unavailable(.deviceNotEligible):
            messages.append(.assistant("❌ Device not supported."))
            return
        case .unavailable(.appleIntelligenceNotEnabled):
            messages.append(.assistant("❌ Enable Apple Intelligence in Settings."))
            return
        case .unavailable(.modelNotReady):
            messages.append(.assistant("⌛ Model is downloading—please wait."))
            return
        default:
            messages.append(.assistant("❌ Model is unavailable."))
            return
        }

        // Append user message and start loader
        messages.append(.user(text))
        isLoading = true

        do {
            let result = try await session.respond(to: Prompt(text))
            messages.append(.assistant(result.content))
        } catch {
            messages.append(.assistant("❌ Error: \(error.localizedDescription)"))
        }

        isLoading = false
    }
}

// MARK: – Model

struct Message: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let content: String

    static func user(_ text: String) -> Message { .init(role: .user, content: text) }
    static func assistant(_ text: String) -> Message { .init(role: .assistant, content: text) }
}

// MARK: – Subviews

/// A single chat bubble with Glass effect and optional glow
struct ChatBubbleView: View {
    let message: Message

    var body: some View {
        let attributed = AttributedString(message.content)
        let tint = message.role == .user ? Color.cyan.opacity(0.4) : Color.white.opacity(0.6)
        let shadowColor = message.role == .assistant ? Color.cyan.opacity(0.9) : .clear

        return HStack {
            if message.role == .user { Spacer() }

            Text(attributed)
                .textSelection(.enabled)
                .padding(12)
                .glassEffect(
                    Glass.regular.tint(tint),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .foregroundStyle(message.role == .user ? .primary : Color.white)
                .shadow(color: shadowColor, radius: message.role == .assistant ? 12 : 0)

            if message.role == .assistant { Spacer() }
        }
    }
}

/// The input bar with glass text field and send button
struct InputBar: View {
    @Binding var draft: String
    var sendAction: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Say something…", text: $draft)
                .padding(10)
                .autocorrectionDisabled(true)
                .glassEffect(
                    Glass.regular
                        .interactive(true)
                        .tint(Color.white.opacity(0.25)),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .frame(maxWidth: .infinity)
            Spacer()

            Button(action: sendAction) {
                Image(systemName: "paperplane.fill")
                    .font(.title2)
                    .padding(4)
            }
            .buttonStyle(.glass)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
    }
}

/// A Siri-like typing indicator with animated dots
struct TypingIndicatorView: View {
    @State private var dotCount = 0
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundColor(.white.opacity(dotCount == index ? 1 : 0.3))
            }
        }
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 3
        }
    }
}

/// A centered glass spinner while loading
struct LoadingView: View {
    var body: some View {
        HStack {
            TypingIndicatorView()
                .padding(12)
                .glassEffect(
                    Glass.regular
                        .tint(Color.white.opacity(0.3))
                        .interactive(true),
                    in: Circle()
                )
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: – Main View

struct ContentView: View {
    @StateObject private var vm = ChatViewModel()
    @State private var draft = ""
    @FocusState private var isInputActive: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.cyan.opacity(0.3),
                    Color.blue.opacity(0.5),
                    Color.cyan.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GlassEffectContainer(spacing: 16) {
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 12) {
                                ForEach(vm.messages) { msg in
                                    ChatBubbleView(message: msg)
                                        .id(msg.id)
                                }
                                if vm.isLoading {
                                    LoadingView()
                                }
                            }
                            .padding(.horizontal, 4)  // optional: small horizontal padding
                        }
                        .scrollDismissesKeyboard(.immediately)
                        .frame(maxHeight: .infinity) // allow scroll area to expand
                        .onChange(of: vm.messages.count) { _ in
                            if let last = vm.messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }

                    InputBar(draft: $draft) {
                        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        draft = ""
                        Task { await vm.send(text) }
                    }
                    .focused($isInputActive)
                }
            }
            .padding(6)
            .onTapGesture { isInputActive = false }
        }
    }
}

#Preview {
    ContentView()
}
