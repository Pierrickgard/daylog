import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @State private var folder = Preferences.folderPath
    @State private var hotKeyLabel = Preferences.hotKeyLabel
    @State private var recording = false
    @State private var monitor: Any?
    @State private var hotKeyError = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            LabeledContent("Raccourci d'ajout rapide") {
                VStack(alignment: .trailing, spacing: 4) {
                    Button(recording ? "Tape le raccourci… (esc pour annuler)" : hotKeyLabel, action: startRecording)
                    if hotKeyError {
                        Text("Ce raccourci est déjà pris par une autre app.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            LabeledContent("Dossier des notes") {
                HStack {
                    Text(folder)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                    Button("Choisir…", action: chooseFolder)
                }
            }

            Toggle("Lancer Daylog à l'ouverture de session", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { setLaunchAtLogin(launchAtLogin) }
            if let loginError {
                Text(loginError).font(.caption).foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        guard !recording else { return }
        recording = true
        HotKey.shared.unregister()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // esc
                stopRecording()
                return nil
            }
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !mods.intersection([.command, .option, .control]).isEmpty else { return nil }
            Preferences.hotKeyCode = UInt32(event.keyCode)
            Preferences.hotKeyModifiers = HotKey.carbonModifiers(mods)
            Preferences.hotKeyLabel = HotKey.label(for: event)
            hotKeyLabel = Preferences.hotKeyLabel
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        hotKeyError = !HotKey.shared.registerFromPreferences()
        (NSApp.delegate as? AppDelegate)?.updateMenuShortcutLabel()
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choisir"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Preferences.folderPath = (url.path as NSString).abbreviatingWithTildeInPath
        folder = Preferences.folderPath
        Store.shared.bootstrap()
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Impossible : \(error.localizedDescription) (l'app doit être dans /Applications)."
        }
    }
}
