import AppKit
import SwiftUI

enum EntryKind: String {
    case daily, todo
}

struct QuickEntryView: View {
    var onClose: () -> Void

    @AppStorage("lastKind") private var kind: EntryKind = .daily
    @AppStorage("lastSection") private var section = ""
    @State private var text = ""
    @State private var sections: [String] = []
    @FocusState private var focused: Bool

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("", selection: $kind) {
                    Text("Daily").tag(EntryKind.daily)
                    Text("To-do").tag(EntryKind.todo)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 150)

                Picker("Section", selection: $section) {
                    ForEach(sections, id: \.self) { Text($0).tag($0) }
                }
                .disabled(kind == .todo)
            }

            TextField(kind == .daily ? "Ce que tu as fait…" : "Ce qu'il reste à faire…", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(submit)

            HStack {
                Text("⌘1 Daily · ⌘2 To-do · ↩ ajouter · esc fermer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Annuler", action: onClose)
                    .keyboardShortcut(.cancelAction)
                Button("Ajouter", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmed.isEmpty)
            }
        }
        .background {
            // Invisible buttons, only there for their shortcuts.
            Group {
                Button("") { kind = .daily }.keyboardShortcut("1", modifiers: .command)
                Button("") { kind = .todo }.keyboardShortcut("2", modifiers: .command)
            }
            .opacity(0)
        }
        .padding(14)
        .frame(width: 460)
        .onAppear {
            sections = Store.shared.sections
            if !sections.contains(section) { section = sections.first ?? "Divers" }
            DispatchQueue.main.async { focused = true }
        }
    }

    private func submit() {
        guard !trimmed.isEmpty else { return }
        switch kind {
        case .daily: Store.shared.addLog(trimmed, section: section.isEmpty ? "Divers" : section)
        case .todo: Store.shared.addTodo(trimmed)
        }
        onClose()
    }
}

final class QuickEntryController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var previousApp: NSRunningApplication?

    var isVisible: Bool { panel?.isVisible == true }

    func toggle() {
        isVisible ? close(restoreFocus: true) : show()
    }

    func show() {
        let front = NSWorkspace.shared.frontmostApplication
        previousApp = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : front

        let panel = self.panel ?? makePanel()
        self.panel = panel
        let host = NSHostingView(rootView: QuickEntryView { [weak self] in self?.close(restoreFocus: true) })
        panel.contentView = host
        panel.setContentSize(host.fittingSize)

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2,
                                         y: visible.minY + visible.height * 0.72 - size.height / 2))
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func close(restoreFocus: Bool) {
        guard let panel, panel.isVisible else { return }
        let app = restoreFocus ? previousApp : nil
        previousApp = nil
        panel.orderOut(nil)
        app?.activate()
    }

    func windowDidResignKey(_ notification: Notification) {
        close(restoreFocus: false) // clicked elsewhere: the other app already has focus
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 460, height: 120),
                            styleMask: [.titled, .closable],
                            backing: .buffered, defer: false)
        panel.title = "Daylog — ajout rapide"
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        return panel
    }
}
