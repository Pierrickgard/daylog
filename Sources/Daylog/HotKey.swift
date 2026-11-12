import AppKit
import Carbon.HIToolbox

/// System-wide shortcut through Carbon's RegisterEventHotKey (no accessibility permission needed).
final class HotKey {
    static let shared = HotKey()

    var handler: (() -> Void)?
    private var ref: EventHotKeyRef?
    private var handlerInstalled = false

    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32) -> Bool {
        installHandlerIfNeeded()
        unregister()
        let id = EventHotKeyID(signature: OSType(0x4459_4C47), id: 1) // "DYLG"
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref)
        return status == noErr
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }

    @discardableResult
    func registerFromPreferences() -> Bool {
        register(keyCode: Preferences.hotKeyCode, modifiers: Preferences.hotKeyModifiers)
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKey.shared.handler?() }
            return noErr
        }, 1, &spec, nil, nil)
        handlerInstalled = true
    }

    static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        return m
    }

    static func label(for event: NSEvent) -> String {
        let f = event.modifierFlags
        var s = ""
        if f.contains(.control) { s += "⌃" }
        if f.contains(.option) { s += "⌥" }
        if f.contains(.shift) { s += "⇧" }
        if f.contains(.command) { s += "⌘" }
        switch Int(event.keyCode) {
        case kVK_Space: s += L10n.t("Space", "Espace")
        case kVK_Return: s += "↩"
        case kVK_Tab: s += "⇥"
        default: s += (event.charactersIgnoringModifiers ?? "?").uppercased()
        }
        return s
    }
}
