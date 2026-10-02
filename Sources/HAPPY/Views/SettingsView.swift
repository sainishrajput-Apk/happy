import SwiftUI

public struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel = .shared
    @State private var selectedTab: SettingsTab = .provider
    @State private var isKeyVisible: Bool = false

    public enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case provider = "AI Provider"
        case about = "About"

        public var id: String { rawValue }

        public var iconName: String {
            switch self {
            case .general: return "gearshape"
            case .provider: return "cpu"
            case .about: return "info.circle"
            }
        }
    }

    public init(viewModel: SettingsViewModel = .shared) {
        self.viewModel = viewModel
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            generalTab
                .tabItem {
                    Label(SettingsTab.general.rawValue, systemImage: SettingsTab.general.iconName)
                }
                .tag(SettingsTab.general)

            providerTab
                .tabItem {
                    Label(SettingsTab.provider.rawValue, systemImage: SettingsTab.provider.iconName)
                }
                .tag(SettingsTab.provider)

            aboutTab
                .tabItem {
                    Label(SettingsTab.about.rawValue, systemImage: SettingsTab.about.iconName)
                }
                .tag(SettingsTab.about)
        }
        .frame(width: 520, height: 380)
        .padding(20)
    }

    // MARK: - General Tab
    private var generalTab: some View {
        Form {
            Section {
                Picker("Appearance", selection: $viewModel.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.rawValue).tag(appearance)
                    }
                }
                .pickerStyle(.menu)

                Toggle("Launch at Login", isOn: $viewModel.launchAtLogin)
                    .help("Automatically launch HAPPY when you log in to your Mac")
            } header: {
                Text("System & Window")
                    .font(.headline)
            }

            Section {
                Picker("Global Shortcut", selection: $viewModel.selectedShortcutId) {
                    ForEach(PresetShortcut.allPresets) { preset in
                        Text(preset.title).tag(preset.id)
                    }
                }
                .pickerStyle(.menu)

                Text("Press this keyboard combination anywhere on your Mac to toggle HAPPY.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("HotKey Shortcut")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - AI Provider Tab
    private var providerTab: some View {
        Form {
            Section {
                Picker("Active Provider", selection: $viewModel.selectedProvider) {
                    ForEach(AIProviderKind.allCases, id: \.self) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Model Provider")
                    .font(.headline)
            }

            Section {
                switch viewModel.selectedProvider {
                case .ollama:
                    ollamaConfigurationFields
                case .gemini:
                    geminiConfigurationFields
                case .mock:
                    mockConfigurationFields
                }
            } header: {
                Text("Provider Configuration")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
    }

    private var ollamaConfigurationFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent("API Endpoint") {
                TextField("http://localhost:11434/v1", text: $viewModel.ollamaBaseURL)
                    .textFieldStyle(.roundedBorder)
            }

            LabeledContent("Model Name") {
                TextField("llama3.2:3b", text: $viewModel.ollamaModel)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text("Make sure Ollama is running locally (`ollama serve`).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var geminiConfigurationFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent("Model Name") {
                TextField("gemini-1.5-flash", text: $viewModel.geminiModel)
                    .textFieldStyle(.roundedBorder)
            }

            LabeledContent("API Key") {
                HStack {
                    if isKeyVisible {
                        TextField("Enter Gemini API key", text: $viewModel.geminiAPIKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("Enter Gemini API key", text: $viewModel.geminiAPIKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button(action: { isKeyVisible.toggle() }) {
                        Image(systemName: isKeyVisible ? "eye.slash" : "eye")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help(isKeyVisible ? "Hide API key" : "Show API key")

                    if !viewModel.geminiAPIKey.isEmpty {
                        Button("Clear", role: .destructive) {
                            viewModel.clearGeminiKey()
                        }
                        .controlSize(.small)
                    }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: viewModel.geminiAPIKey.isEmpty ? "exclamationmark.triangle" : "lock.shield.fill")
                    .foregroundStyle(viewModel.geminiAPIKey.isEmpty ? .orange : .green)
                    .font(.caption)

                Text(viewModel.geminiAPIKey.isEmpty ? "API key not set" : "Stored securely in macOS Keychain")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var mockConfigurationFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.tint)
                    .font(.title3)
                Text("Mock Provider Mode")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Text("Uses canned simulated streaming responses for offline testing, UI verification, and rapid development.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - About Tab
    private var aboutTab: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tint)

            VStack(spacing: 4) {
                Text("HAPPY")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Version 1.0.0 (Milestone 4)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Native system-wide AI assistant for macOS.\nBuilt with Swift, SwiftUI, AppKit, and Keychain Security.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)

            Divider()
                .padding(.horizontal, 40)

            HStack(spacing: 16) {
                Link(destination: URL(string: "https://apple.com")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                        Text("Documentation")
                    }
                    .font(.caption)
                }

                Link(destination: URL(string: "https://github.com")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                        Text("Support")
                    }
                    .font(.caption)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
