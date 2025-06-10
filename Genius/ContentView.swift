//
//  ContentView.swift
//  Genius
//
//  Created by Shadman Ahmed on 6/10/25.
//

import SwiftUI
import Combine
import FoundationModels

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    
    private let session: LanguageModelSession
    private let model = SystemLanguageModel.default

    init() {
        session = LanguageModelSession(model: model,
                                       instructions: "You are a helpful AI assistant that chats like ChatGPT.")
    }

    func send(_ text: String) async {
        guard !text.isEmpty else { return }
        switch model.availability {
        case .available:
            break
        case .unavailable(.deviceNotEligible):
            messages.append(.assistant("❌ Your device doesn’t support Apple Intelligence."))
            return
        case .unavailable(.appleIntelligenceNotEnabled):
            messages.append(.assistant("❌ Please enable Apple Intelligence in Settings."))
            return
        case .unavailable(.modelNotReady):
            messages.append(.assistant("⌛ Model is downloading—please wait."))
            return
        default:
            messages.append(.assistant("❌ Model is unavailable."))
            return
        }

        messages.append(.user(text))
        do {
            let result = try await session.respond(to: Prompt(text))
            messages.append(.assistant(result.content))
        } catch {
            messages.append(.assistant("❌ Error: \(error.localizedDescription)"))
        }
    }
}

struct Message: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let content: String
    
    static func user(_ text: String) -> Message { .init(role: .user, content: text) }
    static func assistant(_ text: String) -> Message { .init(role: .assistant, content: text) }
}

struct ContentView: View {
    @StateObject private var vm = ChatViewModel()
    @State private var draft = ""
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(vm.messages) { msg in
                            HStack {
                                if msg.role == .assistant { Spacer() }
                                Text(msg.content)
                                    .padding()
                                    .background(
                                        msg.role == .user
                                            ? Color.blue.opacity(0.2)
                                            : Color.gray.opacity(0.2)
                                    )
                                    .cornerRadius(10)
                                if msg.role == .user { Spacer() }
                            }
                            .id(msg.id)
                        }
                    }
                    .padding()
                    .onChange(of: vm.messages.count) { _ in
                        if let last = vm.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            HStack {
                TextField("Say something…", text: $draft)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocorrectionDisabled(true)
                Button("Send") {
                    let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    draft = ""
                    Task { await vm.send(text) }
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
