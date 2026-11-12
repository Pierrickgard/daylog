import Foundation

enum Preferences {
    private static let defaults = UserDefaults.standard

    static var folderPath: String {
        get { defaults.string(forKey: "folderPath") ?? "~/Documents/Daylog" }
        set { defaults.set(newValue, forKey: "folderPath") }
    }

    /// Carbon key code and modifiers. Default: ⌃⌥N.
    static var hotKeyCode: UInt32 {
        get { UInt32(defaults.object(forKey: "hotKeyCode") as? Int ?? 45) }
        set { defaults.set(Int(newValue), forKey: "hotKeyCode") }
    }

    static var hotKeyModifiers: UInt32 {
        get { UInt32(defaults.object(forKey: "hotKeyModifiers") as? Int ?? 6144) }
        set { defaults.set(Int(newValue), forKey: "hotKeyModifiers") }
    }

    static var hotKeyLabel: String {
        get { defaults.string(forKey: "hotKeyLabel") ?? "⌃⌥N" }
        set { defaults.set(newValue, forKey: "hotKeyLabel") }
    }

    static var hasLaunchedBefore: Bool {
        get { defaults.bool(forKey: "hasLaunchedBefore") }
        set { defaults.set(newValue, forKey: "hasLaunchedBefore") }
    }

    static var welcomeDismissed: Bool {
        get { defaults.bool(forKey: "welcomeDismissed") }
        set { defaults.set(newValue, forKey: "welcomeDismissed") }
    }

    /// Last kind / section picked in the quick entry.
    static var lastKind: String {
        get { defaults.string(forKey: "lastKind") ?? "daily" }
        set { defaults.set(newValue, forKey: "lastKind") }
    }

    static var lastSection: String {
        get { defaults.string(forKey: "lastSection") ?? "" }
        set { defaults.set(newValue, forKey: "lastSection") }
    }
}
