import AppKit
import ServiceManagement
import WebKit

/// Handles `daylog.call(cmd, args)` from the web UI. Every call gets a JSON-compatible reply.
final class Bridge: NSObject, WKScriptMessageHandlerWithReply {
    weak var app: AppDelegate?
    private var recorder: Any?

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        guard let body = message.body as? [String: Any], let cmd = body["cmd"] as? String else {
            return replyHandler(nil, "bad message")
        }
        let args = body["args"] as? [String: Any] ?? [:]
        let fromQuick = message.webView === app?.quickEntry.webView
        handle(cmd, args) { result in
            replyHandler(result ?? NSNull(), nil)
            // The main window refreshes itself after its own calls; tell it about quick-entry changes.
            if fromQuick && ["addLog", "addTodo"].contains(cmd) { self.app?.notifyMainWindow() }
        }
    }

    private func handle(_ cmd: String, _ a: [String: Any], reply: @escaping (Any?) -> Void) {
        let store = Store.shared
        let str = { (k: String) in a[k] as? String ?? "" }

        switch cmd {
        case "state":
            reply(state())

        case "readDay":
            let key = str("key")
            let url = store.dayURL(key)
            let exists = FileManager.default.fileExists(atPath: url.path)
            reply(["key": key, "title": store.title(for: key), "exists": exists,
                   "text": exists ? store.read(url) : store.newDayContent(key)])

        case "writeDay":
            store.write(str("text"), to: store.dayURL(str("key")))
            reply(true)

        case "addLog":
            let section = str("section")
            store.addLog(str("text"), section: section, day: a["key"] as? String)
            if a["key"] == nil { Preferences.lastSection = section; Preferences.lastKind = "daily" }
            reply(true)

        case "readTemplate":
            reply(store.read(store.templateURL))

        case "writeTemplate":
            store.write(str("text"), to: store.templateURL)
            reply(true)

        case "addTodo":
            store.addTodo(str("text"))
            if a["fromQuick"] as? Bool == true { Preferences.lastKind = "todo" }
            reply(true)
        case "setTodoDone":
            store.setDone(str("id"), a["done"] as? Bool ?? false); reply(true)
        case "renameTodo":
            store.renameTodo(str("id"), str("text")); reply(true)
        case "deleteTodo":
            store.deleteTodo(str("id")); reply(true)
        case "clearDoneTodos":
            store.clearDone(); reply(true)

        case "reveal":
            let key = str("key")
            let url = key.isEmpty ? store.folder : store.dayURL(key)
            if FileManager.default.fileExists(atPath: url.path) {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } else {
                NSWorkspace.shared.open(store.folder)
            }
            reply(true)

        case "setTheme":
            let theme = str("theme")
            Preferences.theme = ["light", "dark"].contains(theme) ? theme : "system"
            app?.applyTheme()
            reply(true)

        case "dismissWelcome":
            Preferences.welcomeDismissed = true; reply(true)

        case "openQuickEntry":
            app?.quickEntry.show(); reply(true)

        case "closeQuickEntry":
            app?.quickEntry.close(restoreFocus: true); reply(true)

        case "resizeQuickEntry":
            app?.quickEntry.setHeight(a["height"] as? Double ?? 160); reply(true)

        case "recordShortcut":
            recordShortcut(reply)

        case "chooseFolder":
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.canCreateDirectories = true
            panel.directoryURL = store.folder
            if panel.runModal() == .OK, let url = panel.url {
                Preferences.folderPath = (url.path as NSString).abbreviatingWithTildeInPath
                store.bootstrap()
            }
            reply(state())

        case "setLaunchAtLogin":
            do {
                if a["on"] as? Bool == true { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
                reply(["ok": true])
            } catch {
                reply(["ok": false, "error": error.localizedDescription])
            }

        case "checkUpdate":
            Updater.shared.check(); reply(true)
        case "installUpdate":
            Updater.shared.install(); reply(true)
        case "setCheckForUpdates":
            Preferences.checkForUpdates = a["on"] as? Bool ?? true
            if Preferences.checkForUpdates { Updater.shared.check(manual: false) }
            reply(true)
        case "openReleases":
            NSWorkspace.shared.open(Updater.releasesPage); reply(true)

        case "openURL":
            // Only web links: notes may come from a synced folder, never let them open files or other apps.
            if let url = URL(string: str("url")), ["http", "https"].contains(url.scheme?.lowercased()) {
                NSWorkspace.shared.open(url)
            }
            reply(true)

        default:
            reply(nil)
        }
    }

    func state() -> [String: Any] {
        let store = Store.shared
        store.reload()
        return [
            "lang": L10n.lang,
            "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev",
            "today": store.todayKey,
            "todayTitle": store.title(for: store.todayKey),
            "days": store.dayKeys.map { ["key": $0, "short": store.shortTitle(for: $0), "title": store.title(for: $0)] },
            "todos": store.todos.map { ["id": $0.id, "text": $0.text, "done": $0.done] },
            "sections": store.sections,
            "lastKind": Preferences.lastKind,
            "lastSection": Preferences.lastSection,
            "shortcut": Preferences.hotKeyLabel,
            "shortcutOK": app?.hotKeyRegistered ?? true,
            "folder": Preferences.folderPath,
            "launchAtLogin": SMAppService.mainApp.status == .enabled,
            "welcome": !Preferences.welcomeDismissed,
            "checkForUpdates": Preferences.checkForUpdates,
            "theme": Preferences.theme,
            "update": updateState(),
        ]
    }

    private func updateState() -> [String: Any] {
        switch Updater.shared.status {
        case .idle: return ["status": "idle"]
        case .checking: return ["status": "checking"]
        case .upToDate: return ["status": "upToDate"]
        case .installing: return ["status": "installing"]
        case .available(let r): return ["status": "available", "version": r.version]
        case .failed(let message): return ["status": "failed", "error": message]
        }
    }

    /// Captures the next key combination pressed in the app (esc cancels).
    private func recordShortcut(_ reply: @escaping (Any?) -> Void) {
        if let recorder { NSEvent.removeMonitor(recorder) }
        HotKey.shared.unregister()
        recorder = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            let isEscape = event.keyCode == 53
            if !isEscape && mods.intersection([.command, .option, .control]).isEmpty { return nil }
            if !isEscape {
                Preferences.hotKeyCode = UInt32(event.keyCode)
                Preferences.hotKeyModifiers = HotKey.carbonModifiers(mods)
                Preferences.hotKeyLabel = HotKey.label(for: event)
            }
            if let recorder = self.recorder { NSEvent.removeMonitor(recorder) }
            self.recorder = nil
            self.app?.registerHotKey()
            reply(self.state())
            return nil
        }
    }
}
