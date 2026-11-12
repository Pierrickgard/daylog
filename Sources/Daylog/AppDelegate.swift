import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var quickEntryItem: NSMenuItem!
    private var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private let quickEntry = QuickEntryController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.mainMenu = makeMainMenu()
        Store.shared.bootstrap()
        setupStatusItem()

        HotKey.shared.handler = { [weak self] in self?.quickEntry.toggle() }
        HotKey.shared.registerFromPreferences()

        if !Preferences.hasLaunchedBefore {
            Preferences.hasLaunchedBefore = true
            showMainWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: Windows

    @objc func quickAdd() { quickEntry.show() }

    @objc func showMainWindow() {
        if mainWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = "Daylog"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: MainView())
            window.center()
            window.setFrameAutosaveName("DaylogMain")
            window.delegate = self
            mainWindow = window
        }
        Store.shared.reload() // pick up edits made outside the app
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable],
                                  backing: .buffered, defer: false)
            window.title = "Réglages"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView())
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === mainWindow {
            NSApp.setActivationPolicy(.accessory) // back to menu bar only
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        if (notification.object as? NSWindow) === mainWindow { Store.shared.reload() }
    }

    // MARK: Menus

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "Daylog")

        let menu = NSMenu()
        quickEntryItem = menu.addItem(withTitle: "", action: #selector(quickAdd), keyEquivalent: "")
        menu.addItem(withTitle: "Ouvrir Daylog", action: #selector(showMainWindow), keyEquivalent: "")
        menu.addItem(withTitle: "Réglages…", action: #selector(showSettings), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quitter Daylog", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) { item.target = self }
        statusItem.menu = menu
        updateMenuShortcutLabel()
    }

    func updateMenuShortcutLabel() {
        quickEntryItem?.title = "Ajout rapide (\(Preferences.hotKeyLabel))"
    }

    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Réglages…", action: #selector(showSettings), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Masquer Daylog", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quitter Daylog", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(withTitle: "Daylog", action: nil, keyEquivalent: "").submenu = appMenu

        let fileMenu = NSMenu(title: "Fichier")
        fileMenu.addItem(withTitle: "Ajout rapide", action: #selector(quickAdd), keyEquivalent: "n").target = self
        fileMenu.addItem(withTitle: "Fermer", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        main.addItem(withTitle: "Fichier", action: nil, keyEquivalent: "").submenu = fileMenu

        let editMenu = NSMenu(title: "Édition")
        editMenu.addItem(withTitle: "Annuler", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Rétablir", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Couper", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copier", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Coller", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Tout sélectionner", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(withTitle: "Édition", action: nil, keyEquivalent: "").submenu = editMenu

        return main
    }
}
