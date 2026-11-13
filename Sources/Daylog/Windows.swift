import AppKit
import WebKit

enum WebUI {
    /// Web assets: `Contents/Resources/web` in the app bundle, or `Web/` in the current directory when run with
    /// `swift run` from the repository (no source path is compiled into the binary).
    static var folder: URL {
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("web"),
           FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Web")
    }

    static func makeWebView(page: String, bridge: Bridge) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.addScriptMessageHandler(bridge, contentWorld: .page, name: "daylog")
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = NavigationGuard.shared
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = false
        webView.loadFileURL(folder.appendingPathComponent(page), allowingReadAccessTo: folder)
        return webView
    }
}

/// The web views only ever show the app's own pages: any other navigation is refused, so no remote page can
/// reach the native bridge. Clicked http(s) links open in the default browser instead.
final class NavigationGuard: NSObject, WKNavigationDelegate {
    static let shared = NavigationGuard()

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { return decisionHandler(.cancel) }
        let root = WebUI.folder.standardizedFileURL.path + "/"
        if url.isFileURL && url.standardizedFileURL.path.hasPrefix(root) && action.targetFrame?.isMainFrame == true {
            return decisionHandler(.allow)
        }
        if action.navigationType == .linkActivated, ["http", "https"].contains(url.scheme?.lowercased()) {
            NSWorkspace.shared.open(url)
        }
        decisionHandler(.cancel)
    }
}

/// Transparent strip over the top of the main window so it can be dragged by its (hidden) title bar.
final class TitleBarDragView: NSView {
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            window?.performZoom(nil)
        } else {
            window?.performDrag(with: event)
        }
    }
}

final class MainWindowController: NSObject, NSWindowDelegate {
    let window: NSWindow
    let webView: WKWebView

    init(bridge: Bridge) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 640),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        webView = WebUI.makeWebView(page: "index.html", bridge: bridge)
        super.init()

        window.title = "Daylog"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 640, height: 420)
        window.backgroundColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(srgbRed: 0.106, green: 0.110, blue: 0.122, alpha: 1)
                : NSColor(srgbRed: 0.957, green: 0.953, blue: 0.941, alpha: 1)
        }

        let content = NSView()
        webView.frame = content.bounds
        webView.autoresizingMask = [.width, .height]
        content.addSubview(webView)
        let drag = TitleBarDragView(frame: NSRect(x: 80, y: 0, width: 10, height: 28))
        drag.autoresizingMask = [.width, .minYMargin]
        content.addSubview(drag)
        window.contentView = content
        drag.frame = NSRect(x: 80, y: content.bounds.height - 28, width: content.bounds.width - 80, height: 28)

        window.center()
        window.setFrameAutosaveName("DaylogMain")
        window.delegate = self
    }

    /// Called when the window closes: the app then goes back to living in the menu bar only.
    var onClose: (() -> Void)?

    func show() {
        // Daylog only has a Dock icon while its window is open (like a menu bar app the rest of the time).
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            self.window.makeKeyAndOrderFront(nil)
            self.window.orderFrontRegardless()
        }
        refresh()
    }

    func close() {
        window.performClose(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    func refresh() {
        webView.evaluateJavaScript("window.daylogRefresh && window.daylogRefresh()")
    }

    func windowDidBecomeKey(_ notification: Notification) {
        refresh() // pick up edits made in other apps
    }
}

/// Borderless panel: can take keyboard focus, closes as soon as it loses it.
final class QuickPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class QuickEntryController: NSObject, NSWindowDelegate {
    let panel: QuickPanel
    let webView: WKWebView
    private var previousApp: NSRunningApplication?

    init(bridge: Bridge) {
        panel = QuickPanel(contentRect: NSRect(x: 0, y: 0, width: 560, height: 170),
                           styleMask: [.borderless, .nonactivatingPanel],
                           backing: .buffered, defer: false)
        webView = WebUI.makeWebView(page: "quick.html", bridge: bridge)
        super.init()

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        webView.frame = panel.contentView!.bounds
        webView.autoresizingMask = [.width, .height]
        panel.contentView!.addSubview(webView)
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        isVisible ? close(restoreFocus: true) : show()
    }

    func show() {
        let front = NSWorkspace.shared.frontmostApplication
        previousApp = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : front

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let size = panel.frame.size
            panel.setFrameTopLeftPoint(NSPoint(x: visible.midX - size.width / 2,
                                               y: visible.maxY - visible.height * 0.22))
        }

        webView.evaluateJavaScript("window.quickOpen && window.quickOpen()")
        // Non-activating panel: it takes the keyboard without bringing Daylog (and its main window) forward.
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(webView)
    }

    func setHeight(_ height: Double) {
        var frame = panel.frame
        let top = frame.maxY
        frame.size.height = CGFloat(height)
        frame.origin.y = top - frame.size.height
        panel.setFrame(frame, display: true)
    }

    func close(restoreFocus: Bool) {
        guard panel.isVisible else { return }
        let app = restoreFocus ? previousApp : nil
        previousApp = nil
        panel.orderOut(nil)
        app?.activate()
    }

    func windowDidResignKey(_ notification: Notification) {
        close(restoreFocus: false) // clicked elsewhere: that app already has focus
    }
}
