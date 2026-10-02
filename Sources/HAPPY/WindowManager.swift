import AppKit
import SwiftUI

/// NSPanel subclass configured specifically for the floating glass HUD experience.
final class HappyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        WindowManager.shared.hide()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            WindowManager.shared.hide()
            return
        }
        super.keyDown(with: event)
    }
}

/// Coordinates panel creation, positioning, smooth animation, and display state.
@MainActor
final class WindowManager: NSObject {
    static let shared = WindowManager()

    private var panel: HappyPanel?
    private var visualEffectView: NSVisualEffectView?
    private var isVisible = false
    private var settingsWindow: NSWindow?

    private let panelWidth: CGFloat = 640

    private override init() {
        super.init()
    }

    /// Displays the native Settings window.
    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 380),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "HAPPY Settings"
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView())
            self.settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Sets up the floating panel with visual effect view and SwiftUI content.
    func setup() {
        guard panel == nil else { return }

        let panelHeight: CGFloat = 480
        let initialRect = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        let panel = HappyPanel(
            contentRect: initialRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true

        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 16
        effectView.layer?.masksToBounds = true

        let hostingView = NSHostingView(rootView: HappyPanelView())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: effectView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor)
        ])

        panel.contentView = effectView
        self.panel = panel
        self.visualEffectView = effectView
    }

    /// Toggles visibility of the panel.
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    /// Shows the panel with a smooth fade + scale animation on the active screen.
    func show() {
        if panel == nil {
            setup()
        }
        guard let panel else { return }

        positionOnActiveScreen()

        panel.alphaValue = 0.0
        if let contentView = panel.contentView {
            contentView.wantsLayer = true
            contentView.layer?.transform = CATransform3DMakeScale(0.96, 0.96, 1.0)
        }

        panel.orderFrontRegardless()
        panel.makeKey()
        isVisible = true

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
            panel.contentView?.layer?.transform = CATransform3DIdentity
        }
    }

    /// Hides the panel with a smooth fade + scale animation.
    func hide() {
        guard let panel, isVisible else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0.0
            panel.contentView?.layer?.transform = CATransform3DMakeScale(0.96, 0.96, 1.0)
        }, completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.panel?.orderOut(nil)
                self.isVisible = false
            }
        })
    }

    /// Positions the panel in the upper-third of the target active screen.
    private func positionOnActiveScreen() {
        guard let panel else { return }

        let screen = targetScreen()
        let screenFrame = screen.visibleFrame
        let effectiveHeight: CGFloat = 480

        let x = screenFrame.origin.x + (screenFrame.width - panelWidth) / 2
        // Position upper third similar to Spotlight (70% up from bottom of visible frame)
        let y = screenFrame.origin.y + (screenFrame.height - effectiveHeight) * 0.72

        let newFrame = NSRect(x: x, y: y, width: panelWidth, height: effectiveHeight)
        panel.setFrame(newFrame, display: true)
    }

    /// Determines the screen containing the cursor or frontmost active app.
    private func targetScreen() -> NSScreen {
        let mouseLoc = NSEvent.mouseLocation
        if let screenWithMouse = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) {
            return screenWithMouse
        }
        return NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
    }
}
