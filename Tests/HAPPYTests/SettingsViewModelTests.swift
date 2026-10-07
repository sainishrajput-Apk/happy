import XCTest
@testable import HAPPY

@MainActor
final class SettingsViewModelTests: XCTestCase {
    private var testSuiteName: String!
    private var testDefaults: UserDefaults!
    private var testServiceName: String!
    private var testKeychain: KeychainManager!
    private var viewModel: SettingsViewModel!

    override func setUp() async throws {
        try await super.setUp()
        testSuiteName = "com.happy.test.settings.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testSuiteName)!
        testServiceName = "com.happy.test.keychain.\(UUID().uuidString)"
        testKeychain = KeychainManager(serviceName: testServiceName)

        viewModel = SettingsViewModel(userDefaults: testDefaults, keychain: testKeychain)
    }

    override func tearDown() async throws {
        testKeychain.deleteAll()
        testDefaults.removePersistentDomain(forName: testSuiteName)
        viewModel = nil
        testKeychain = nil
        testDefaults = nil
        testServiceName = nil
        testSuiteName = nil
        try await super.tearDown()
    }

    func testDefaultSettings() {
        XCTAssertEqual(viewModel.selectedProvider, .ollama)
        XCTAssertEqual(viewModel.ollamaBaseURL, "http://localhost:11434/v1")
        XCTAssertEqual(viewModel.ollamaModel, "llama3.2:3b")
        XCTAssertEqual(viewModel.geminiModel, "gemini-1.5-flash")
        XCTAssertEqual(viewModel.geminiAPIKey, "")
        XCTAssertEqual(viewModel.appearance, .system)
        XCTAssertEqual(viewModel.selectedShortcutId, PresetShortcut.cmdShiftSpace.id)
        XCTAssertFalse(viewModel.launchAtLogin)
    }

    func testProviderSelectionPersistence() {
        viewModel.selectedProvider = .gemini
        XCTAssertEqual(testDefaults.string(forKey: SettingsViewModel.Keys.selectedProvider), AIProviderKind.gemini.rawValue)

        let reloadedVM = SettingsViewModel(userDefaults: testDefaults, keychain: testKeychain)
        XCTAssertEqual(reloadedVM.selectedProvider, .gemini)

        viewModel.selectedProvider = .mock
        XCTAssertEqual(testDefaults.string(forKey: SettingsViewModel.Keys.selectedProvider), AIProviderKind.mock.rawValue)
    }

    func testOllamaConfigurationPersistence() {
        viewModel.ollamaBaseURL = "http://192.168.1.100:11434/v1"
        viewModel.ollamaModel = "mistral:latest"

        XCTAssertEqual(testDefaults.string(forKey: SettingsViewModel.Keys.ollamaBaseURL), "http://192.168.1.100:11434/v1")
        XCTAssertEqual(testDefaults.string(forKey: SettingsViewModel.Keys.ollamaModel), "mistral:latest")

        let reloadedVM = SettingsViewModel(userDefaults: testDefaults, keychain: testKeychain)
        XCTAssertEqual(reloadedVM.ollamaBaseURL, "http://192.168.1.100:11434/v1")
        XCTAssertEqual(reloadedVM.ollamaModel, "mistral:latest")
    }

    func testGeminiConfigurationAndKeychainPersistence() {
        viewModel.geminiModel = "gemini-1.5-pro"
        XCTAssertEqual(testDefaults.string(forKey: SettingsViewModel.Keys.geminiModel), "gemini-1.5-pro")

        // Storing Gemini API key should update Keychain
        let secretKey = "test-gemini-key"
        viewModel.geminiAPIKey = secretKey

        // Direct keychain check using test service name
        XCTAssertEqual(testKeychain.get(key: SettingsViewModel.Keys.geminiAPIKey), secretKey)

        // Reloading ViewModel from same Keychain should populate key
        let reloadedVM = SettingsViewModel(userDefaults: testDefaults, keychain: testKeychain)
        XCTAssertEqual(reloadedVM.geminiAPIKey, secretKey)
        XCTAssertEqual(reloadedVM.geminiModel, "gemini-1.5-pro")

        // Clearing key deletes from Keychain
        viewModel.clearGeminiKey()
        XCTAssertEqual(viewModel.geminiAPIKey, "")
        XCTAssertNil(testKeychain.get(key: SettingsViewModel.Keys.geminiAPIKey))
    }

    func testAppearanceSettingPersistence() {
        viewModel.appearance = .dark
        XCTAssertEqual(testDefaults.string(forKey: SettingsViewModel.Keys.appearance), AppAppearance.dark.rawValue)
        XCTAssertNotNil(viewModel.appearance.nsAppearance)

        viewModel.appearance = .light
        XCTAssertEqual(testDefaults.string(forKey: SettingsViewModel.Keys.appearance), AppAppearance.light.rawValue)
        XCTAssertNotNil(viewModel.appearance.nsAppearance)

        viewModel.appearance = .system
        XCTAssertNil(viewModel.appearance.nsAppearance)
    }

    func testShortcutSelectionPersistence() {
        viewModel.selectedShortcutId = PresetShortcut.optSpace.id
        XCTAssertEqual(testDefaults.string(forKey: SettingsViewModel.Keys.shortcutId), PresetShortcut.optSpace.id)

        let reloadedVM = SettingsViewModel(userDefaults: testDefaults, keychain: testKeychain)
        XCTAssertEqual(reloadedVM.selectedShortcutId, PresetShortcut.optSpace.id)
    }

    func testLaunchAtLoginTogglePersistence() {
        viewModel.launchAtLogin = true
        XCTAssertTrue(testDefaults.bool(forKey: SettingsViewModel.Keys.launchAtLogin))

        let reloadedVM = SettingsViewModel(userDefaults: testDefaults, keychain: testKeychain)
        XCTAssertTrue(reloadedVM.launchAtLogin)

        viewModel.launchAtLogin = false
        XCTAssertFalse(testDefaults.bool(forKey: SettingsViewModel.Keys.launchAtLogin))
    }
}
