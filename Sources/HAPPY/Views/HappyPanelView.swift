import SwiftUI

struct HappyPanelView: View {
    @StateObject private var viewModel = ChatViewModel.live()

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.tint)

                Text("HAPPY")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Preview")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())

                Spacer()

                if !viewModel.messages.isEmpty {
                    Button(action: {
                        viewModel.clearConversation()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                            Text("Clear")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .help("Clear conversation")
                }

                Button(action: {
                    WindowManager.shared.showSettings()
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("Settings (,)")

                HStack(spacing: 4) {
                    Text("Esc")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text("to close")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()
                .opacity(0.2)

            // Chat Scrollable Area
            ChatView(
                viewModel: viewModel,
                onOpenSettings: {
                    WindowManager.shared.showSettings()
                }
            )

            Divider()
                .opacity(0.2)

            // Bottom Input Bar Area
            InputBar(
                text: $viewModel.inputText,
                isStreaming: viewModel.isStreaming,
                onSend: { viewModel.sendMessage() },
                onStop: { viewModel.stopStreaming() }
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(width: 640, height: 480)
        .background(.clear)
    }
}
