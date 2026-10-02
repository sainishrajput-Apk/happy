import AppKit
import Cocoa

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory application (no Dock icon, menu bar utility)
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        WindowManager.shared.setup()
        HotkeyManager.shared.registerDefaultHotKey()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }

        let icon = NSImage(
            systemSymbolName: "sparkles",
            accessibilityDescription: "HAPPY"
        )
        button.image = icon

        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: "Toggle HAPPY",
            action: #selector(togglePanelAction),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettingsAction),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit HAPPY",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func togglePanelAction() {
        WindowManager.shared.toggle()
    }

    @objc private func openSettingsAction() {
        WindowManager.shared.showSettings()
    }

    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }
}
