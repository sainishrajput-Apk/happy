import Carbon
import Cocoa

/// Manages registration and handling of global hotkeys via Carbon RegisterEventHotKey.
/// Does not require Accessibility permissions.
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var isHandlerInstalled = false

    /// Default hotkey identifier
    private let hotKeySignature: OSType = 0x48415050 // "HAPP"
    private let defaultHotKeyId: UInt32 = 1

    private let keyCodeKey = "happy.hotkey.keyCode"
    private let modifiersKey = "happy.hotkey.modifiers"

    private init() {}

    /// Registers the default or saved hotkey (Cmd + Shift + Space by default).
    @discardableResult
    func registerDefaultHotKey() -> Bool {
        let defaults = UserDefaults.standard
        let keyCode: UInt32
        let modifiers: UInt32

        if defaults.object(forKey: keyCodeKey) != nil {
            keyCode = UInt32(defaults.integer(forKey: keyCodeKey))
            modifiers = UInt32(defaults.integer(forKey: modifiersKey))
        } else {
            // Default: Space (kVK_Space = 49), Cmd + Shift
            keyCode = UInt32(kVK_Space)
            modifiers = UInt32(cmdKey | shiftKey)
            defaults.set(keyCode, forKey: keyCodeKey)
            defaults.set(modifiers, forKey: modifiersKey)
        }

        return registerHotKey(keyCode: keyCode, modifiers: modifiers)
    }

    /// Registers a custom hotkey combination.
    @discardableResult
    func registerHotKey(keyCode: UInt32, modifiers: UInt32) -> Bool {
        installHandlerIfNeeded()
        unregisterHotKey()

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = hotKeySignature
        hotKeyID.id = defaultHotKeyId

        var newRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &newRef
        )

        if status == noErr, let newRef {
            self.hotKeyRef = newRef
            UserDefaults.standard.set(keyCode, forKey: keyCodeKey)
            UserDefaults.standard.set(modifiers, forKey: modifiersKey)
            return true
        } else {
            // Hotkey registration conflict or error
            return false
        }
    }

    /// Unregisters the currently active hotkey.
    func unregisterHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    /// Invoked when the registered hotkey fires.
    func handleHotKey(id: UInt32) {
        guard id == defaultHotKeyId else { return }
        WindowManager.shared.toggle()
    }

    private func installHandlerIfNeeded() {
        guard !isHandlerInstalled else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotKeyCallback,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        if status == noErr {
            isHandlerInstalled = true
        }
    }

    func unregisterAll() {
        unregisterHotKey()
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
            isHandlerInstalled = false
        }
    }
}

/// C callback invoked by Carbon when an event hotkey triggers.
private func carbonHotKeyCallback(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return noErr }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    if status == noErr {
        Task { @MainActor in
            HotkeyManager.shared.handleHotKey(id: hotKeyID.id)
        }
    }

    return noErr
}
