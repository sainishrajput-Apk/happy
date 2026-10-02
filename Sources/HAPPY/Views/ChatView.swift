import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    let onOpenSettings: () -> Void

    private let examplePrompts = [
        "Explain quantum computing in simple terms",
        "Write a Swift function to debounce an async stream",
        "Draft a polite email declining an invitation"
    ]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.messages.isEmpty {
                        emptyStateView
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(
                                    message: message,
                                    onRetry: { viewModel.retryLast() },
                                    onOpenSettings: onOpenSettings
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .onChange(of: viewModel.messages.last?.content) { _, _ in
                if let lastId = viewModel.messages.last?.id {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let lastId = viewModel.messages.last?.id {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 12)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(.tint)
                    Text("HAPPY")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                Text("How can I help you today?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(examplePrompts, id: \.self) { prompt in
                    Button(action: {
                        viewModel.sendMessage(prompt)
                    }) {
                        HStack {
                            Text(prompt)
                                .font(.system(size: 12))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
