import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let bridge = Bridge()
    private(set) lazy var quickEntry = QuickEntryController(bridge: bridge)
    private lazy var mainWindow = MainWindowController(bridge: bridge)
    private var statusItem: NSStatusItem!
    private var quickEntryItem: NSMenuItem!
    private(set) var hotKeyRegistered = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        bridge.app = self
        NSApp.setActivationPolicy(.regular)
        applyTheme()
        NSApp.mainMenu = makeMainMenu()
        Store.shared.bootstrap()
        setupStatusItem()

        HotKey.shared.handler = { [weak self] in self?.quickEntry.toggle() }
        registerHotKey()
        _ = quickEntry // load the popup's page now so it opens instantly

        Updater.shared.onChange = { [weak self] in self?.notifyMainWindow() }
        Updater.shared.startAutomaticChecks()

        // Launched at login or through a daylog:// link: stay in the background. Launched by hand: show the window.
        let launchedAtLogin = NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: keyAELaunchedAsLogInItem) != nil
        if UserDefaults.standard.bool(forKey: "showQuickLogAtLaunch") { // used for the README screenshots
            openedByURL = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.quickEntry.show() }
        }
        if !launchedAtLogin {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if !self.openedByURL { self.showMainWindow() }
            }
        }
    }

    private var openedByURL = false

    /// daylog://quick opens the quick log, daylog://open the main window (handy for Raycast, Alfred, Shortcuts…).
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "daylog" {
            openedByURL = true
            switch url.host {
            case "quick": quickEntry.show()
            case "settings": showSettings()
            default: showMainWindow()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func registerHotKey() {
        hotKeyRegistered = HotKey.shared.registerFromPreferences()
        quickEntryItem?.title = L10n.t("Quick Log", "Ajout rapide") + "  \(Preferences.hotKeyLabel)"
    }

    func notifyMainWindow() { mainWindow.refresh() }

    /// Light, dark or the system's: set on the whole app, so windows and web views (prefers-color-scheme) follow.
    func applyTheme() {
        switch Preferences.theme {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }

    @objc func quickAdd() { quickEntry.show() }

    @objc func showMainWindow() { mainWindow.show() }

    @objc func showSettings() {
        mainWindow.show()
        mainWindow.webView.evaluateJavaScript("window.daylogGo && window.daylogGo('settings')")
    }

    // MARK: Menus

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = Self.menuBarIcon()

        let menu = NSMenu()
        quickEntryItem = menu.addItem(withTitle: "", action: #selector(quickAdd), keyEquivalent: "")
        menu.addItem(withTitle: L10n.t("Open Daylog", "Ouvrir Daylog"), action: #selector(showMainWindow), keyEquivalent: "")
        menu.addItem(withTitle: L10n.t("Settings…", "Réglages…"), action: #selector(showSettings), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: L10n.t("Quit Daylog", "Quitter Daylog"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) { item.target = self }
        statusItem.menu = menu
        registerHotKey()
    }

    /// The app icon's checklist, as a monochrome template image that adapts to the menu bar.
    static func menuBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            NSColor.black.set()
            // checked box
            let box = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 2, width: 5, height: 5), xRadius: 1.4, yRadius: 1.4)
            box.fill()
            let check = NSBezierPath()
            check.move(to: NSPoint(x: 2.7, y: 4.6))
            check.line(to: NSPoint(x: 3.7, y: 5.6))
            check.line(to: NSPoint(x: 5.4, y: 3.3))
            check.lineWidth = 1.1
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            NSGraphicsContext.current?.compositingOperation = .clear
            check.stroke()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            // bullets
            NSBezierPath(ovalIn: NSRect(x: 2.5, y: 8, width: 3, height: 3)).fill()
            NSBezierPath(ovalIn: NSRect(x: 2.5, y: 13, width: 3, height: 3)).fill()
            // lines, shorter as they go down
            for (y, width) in [(3.6, 8.0), (8.6, 9.5), (13.6, 6.5)] as [(CGFloat, CGFloat)] {
                NSBezierPath(roundedRect: NSRect(x: 8, y: y, width: width, height: 1.8), xRadius: 0.9, yRadius: 0.9).fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Daylog"
        return image
    }

    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L10n.t("Settings…", "Réglages…"), action: #selector(showSettings), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L10n.t("Hide Daylog", "Masquer Daylog"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: L10n.t("Quit Daylog", "Quitter Daylog"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(withTitle: "Daylog", action: nil, keyEquivalent: "").submenu = appMenu

        let fileMenu = NSMenu(title: L10n.t("File", "Fichier"))
        fileMenu.addItem(withTitle: L10n.t("Quick Log", "Ajout rapide"), action: #selector(quickAdd), keyEquivalent: "n").target = self
        fileMenu.addItem(withTitle: L10n.t("Close", "Fermer"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        main.addItem(withTitle: L10n.t("File", "Fichier"), action: nil, keyEquivalent: "").submenu = fileMenu

        let editMenu = NSMenu(title: L10n.t("Edit", "Édition"))
        editMenu.addItem(withTitle: L10n.t("Undo", "Annuler"), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: L10n.t("Redo", "Rétablir"), action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: L10n.t("Cut", "Couper"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L10n.t("Copy", "Copier"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L10n.t("Paste", "Coller"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L10n.t("Select All", "Tout sélectionner"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(withTitle: L10n.t("Edit", "Édition"), action: nil, keyEquivalent: "").submenu = editMenu

        let windowMenu = NSMenu(title: L10n.t("Window", "Fenêtre"))
        windowMenu.addItem(withTitle: L10n.t("Minimize", "Réduire"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Daylog", action: #selector(showMainWindow), keyEquivalent: "0").target = self
        main.addItem(withTitle: L10n.t("Window", "Fenêtre"), action: nil, keyEquivalent: "").submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        return main
    }
}
