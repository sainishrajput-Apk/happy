import Foundation
import SwiftUI
import ServiceManagement
import Carbon

public enum AppAppearance: String, CaseIterable, Identifiable, Codable, Sendable {
    case system = "System"
    case dark = "Dark"
    case light = "Light"

    public var id: String { rawValue }

    public var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .dark: return NSAppearance(named: .darkAqua)
        case .light: return NSAppearance(named: .aqua)
        }
    }
}

public struct PresetShortcut: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let keyCode: UInt32
    public let modifiers: UInt32

    public static let cmdShiftSpace = PresetShortcut(
        id: "cmd_shift_space",
        title: "⌘ ⇧ Space",
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(cmdKey | shiftKey)
    )
    public static let optSpace = PresetShortcut(
        id: "opt_space",
        title: "⌥ Space",
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(optionKey)
    )
    public static let ctrlSpace = PresetShortcut(
        id: "ctrl_space",
        title: "⌃ Space",
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(controlKey)
    )
    public static let cmdOptSpace = PresetShortcut(
        id: "cmd_opt_space",
        title: "⌘ ⌥ Space",
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(cmdKey | optionKey)
    )

    public static let allPresets: [PresetShortcut] = [
        .cmdShiftSpace,
        .optSpace,
        .ctrlSpace,
        .cmdOptSpace
    ]
}

@MainActor
public final class SettingsViewModel: ObservableObject {
    public static let shared = SettingsViewModel()

    public let userDefaults: UserDefaults
    public let keychain: KeychainManager

    // Provider settings
    @Published public var selectedProvider: AIProviderKind {
        didSet { userDefaults.set(selectedProvider.rawValue, forKey: Keys.selectedProvider) }
    }
    @Published public var ollamaBaseURL: String {
        didSet { userDefaults.set(ollamaBaseURL, forKey: Keys.ollamaBaseURL) }
    }
    @Published public var ollamaModel: String {
        didSet { userDefaults.set(ollamaModel, forKey: Keys.ollamaModel) }
    }
    @Published public var geminiModel: String {
        didSet { userDefaults.set(geminiModel, forKey: Keys.geminiModel) }
    }
    @Published public var geminiAPIKey: String {
        didSet {
            let trimmed = geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                keychain.delete(key: Keys.geminiAPIKey)
            } else {
                keychain.save(key: Keys.geminiAPIKey, value: trimmed)
            }
        }
    }

    // Appearance
    @Published public var appearance: AppAppearance {
        didSet {
            userDefaults.set(appearance.rawValue, forKey: Keys.appearance)
            applyAppearance()
        }
    }

    // Shortcut
    @Published public var selectedShortcutId: String {
        didSet {
            userDefaults.set(selectedShortcutId, forKey: Keys.shortcutId)
            applyShortcut()
        }
    }

    // Launch at login
    @Published public var launchAtLogin: Bool {
        didSet {
            userDefaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            applyLaunchAtLogin(launchAtLogin)
        }
    }

    public enum Keys {
        public static let selectedProvider = "happy.settings.provider"
        public static let ollamaBaseURL = "happy.settings.ollama.url"
        public static let ollamaModel = "happy.settings.ollama.model"
        public static let geminiModel = "happy.settings.gemini.model"
        public static let geminiAPIKey = "happy.credentials.gemini.apiKey"
        public static let appearance = "happy.settings.appearance"
        public static let shortcutId = "happy.settings.shortcutId"
        public static let launchAtLogin = "happy.settings.launchAtLogin"
    }

    public init(
        userDefaults: UserDefaults = .standard,
        keychain: KeychainManager = .shared
    ) {
        self.userDefaults = userDefaults
        self.keychain = keychain

        // Load provider
        if let rawProvider = userDefaults.string(forKey: Keys.selectedProvider),
           let provider = AIProviderKind(rawValue: rawProvider) {
            self.selectedProvider = provider
        } else {
            self.selectedProvider = .ollama
        }

        // Load URLs & models
        self.ollamaBaseURL = userDefaults.string(forKey: Keys.ollamaBaseURL) ?? "http://localhost:11434/v1"
        self.ollamaModel = userDefaults.string(forKey: Keys.ollamaModel) ?? "llama3.2:3b"
        self.geminiModel = userDefaults.string(forKey: Keys.geminiModel) ?? "gemini-1.5-flash"

        // Load Gemini API Key from Keychain
        self.geminiAPIKey = keychain.get(key: Keys.geminiAPIKey) ?? ""

        // Load appearance
        if let rawAppearance = userDefaults.string(forKey: Keys.appearance),
           let appAppearance = AppAppearance(rawValue: rawAppearance) {
            self.appearance = appAppearance
        } else {
            self.appearance = .system
        }

        // Load shortcut
        self.selectedShortcutId = userDefaults.string(forKey: Keys.shortcutId) ?? PresetShortcut.cmdShiftSpace.id

        // Load launch at login
        self.launchAtLogin = userDefaults.bool(forKey: Keys.launchAtLogin)
    }

    public func applyAppearance() {
        NSApplication.shared.appearance = appearance.nsAppearance
    }

    public func applyShortcut() {
        if let preset = PresetShortcut.allPresets.first(where: { $0.id == selectedShortcutId }) {
            HotkeyManager.shared.registerHotKey(keyCode: preset.keyCode, modifiers: preset.modifiers)
        }
    }

    public func clearGeminiKey() {
        geminiAPIKey = ""
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            // In non-bundled or test builds, SMAppService may throw or be unsupported
        }
    }
}
