import SwiftUI

/// Checks that Ollama is reachable and that the chosen model is installed.
struct ConnectionTestButton: View {
    @ObservedObject private var settings = SettingsViewModel.shared
    @State private var status = ""
    @State private var isError = false
    @State private var isTesting = false

    var body: some View {
        HStack(spacing: 10) {
            Button(isTesting ? "Testing..." : "Test connection") {
                Task { await runTest() }
            }
            .disabled(isTesting)

            if !status.isEmpty {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(isError ? Color.red : Color.green)
            }
        }
    }

    @MainActor
    private func runTest() async {
        isTesting = true
        status = ""
        defer { isTesting = false }

        var base = settings.ollamaBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        if !base.hasSuffix("/v1") { base += "/v1" }

        guard let url = URL(string: base + "/models") else {
            show("The Ollama URL is not valid.", error: true)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                show("Ollama answered, but not as expected. Check the URL.", error: true)
                return
            }
            struct ModelList: Decodable {
                struct Item: Decodable { let id: String }
                let data: [Item]
            }
            let ids = (try? JSONDecoder().decode(ModelList.self, from: data))?.data.map { $0.id } ?? []
            if ids.contains(settings.ollamaModel) {
                show("Connected. Model \(settings.ollamaModel) is ready.", error: false)
            } else {
                show("Connected, but model \"\(settings.ollamaModel)\" is not installed. Run: ollama pull \(settings.ollamaModel)", error: true)
            }
        } catch {
            show("Can't reach Ollama. Open the Ollama app and try again.", error: true)
        }
    }

    private func show(_ message: String, error: Bool) {
        status = message
        isError = error
    }
}
