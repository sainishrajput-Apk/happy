import SwiftUI

struct InputBar: View {
    @Binding var text: String
    let isStreaming: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask HAPPY anything...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .lineLimit(1...5)
                .focused($isFocused)
                .onKeyPress(.return, phases: .down) { press in
                    if press.modifiers.contains(.shift) {
                        return .ignored
                    } else {
                        onSend()
                        return .handled
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            // Send / Stop button
            if isStreaming {
                Button(action: onStop) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.red.opacity(0.85))
                }
                .buttonStyle(.plain)
                .help("Stop generating")
                .padding(.trailing, 6)
                .padding(.bottom, 6)
            } else {
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(canSend ? Color.white : Color.secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .help("Send message (Return)")
                .padding(.trailing, 6)
                .padding(.bottom, 6)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.2))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .onAppear {
            isFocused = true
        }
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
