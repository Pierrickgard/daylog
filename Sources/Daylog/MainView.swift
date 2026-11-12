import AppKit
import SwiftUI

enum Page: Hashable {
    case today, todo, template
    case day(String)
}

struct MainView: View {
    @ObservedObject private var store = Store.shared
    @State private var page: Page? = .today

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $page) {
                Section {
                    Label("Aujourd'hui", systemImage: "calendar").tag(Page.today)
                    Label("To-do", systemImage: "checklist")
                        .badge(store.openTodoCount)
                        .tag(Page.todo)
                }
                Section("Historique") {
                    ForEach(store.dayKeys.filter { $0 != store.todayKey }, id: \.self) { key in
                        Text(store.shortTitle(for: key)).tag(Page.day(key))
                    }
                }
                Section {
                    Label("Modèle du daily", systemImage: "doc.text").tag(Page.template)
                }
            }
            .listStyle(.sidebar)
            .frame(width: 210)

            Divider()

            Group {
                switch page ?? .today {
                case .today:
                    // The file is only created once something is written in it.
                    FileEditor(url: store.dayURL(store.todayKey),
                               title: "Aujourd'hui — \(store.title(for: store.todayKey))",
                               initialText: store.newDayContent(store.todayKey))
                case .day(let key):
                    FileEditor(url: store.dayURL(key), title: store.title(for: key))
                case .template:
                    FileEditor(url: store.templateURL, title: "Modèle du daily",
                               hint: "{{date}} est remplacé par la date du jour. Les titres « ## » sont les sections proposées dans l'ajout rapide.")
                case .todo:
                    TodoView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 720, minHeight: 440)
    }
}

/// Header shared by every page: title on the left, actions on the right.
struct PageHeader<Actions: View>: View {
    var title: String
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                actions
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            Divider()
        }
    }
}

/// Plain-text Markdown editor bound to one file, saved on every change.
struct FileEditor: View {
    let url: URL
    let title: String
    var hint: String? = nil
    var initialText = ""

    @ObservedObject private var store = Store.shared
    @State private var text = ""
    @State private var loadedURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: title) {
                Button("Afficher dans le Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
            if let hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                Divider()
            }
            TextEditor(text: $text)
                .font(.system(size: 13, design: .monospaced))
                .padding(8)
        }
        .onAppear(perform: load)
        .onChange(of: url) { load() }
        .onChange(of: store.revision) { load() }
        .onChange(of: text) {
            if loadedURL == url && (text != initialText || FileManager.default.fileExists(atPath: url.path)) {
                store.write(text, to: url)
            }
        }
    }

    private func load() {
        loadedURL = nil
        text = FileManager.default.fileExists(atPath: url.path) ? store.read(url) : initialText
        DispatchQueue.main.async { loadedURL = url }
    }
}

struct TodoView: View {
    @ObservedObject private var store = Store.shared
    @State private var newText = ""
    @AppStorage("showDoneTodos") private var showDone = true

    private var open: [TodoItem] { store.todos.filter { !$0.done } }
    private var done: [TodoItem] { store.todos.filter(\.done) }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "To-do") {
                Toggle("Afficher les terminées", isOn: $showDone)
                Button("Supprimer les terminées", action: store.clearDone)
                    .disabled(done.isEmpty)
            }
            HStack {
                TextField("Nouvelle tâche", text: $newText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Button("Ajouter", action: add)
                    .disabled(newText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(10)
            Divider()
            List {
                Section("À faire (\(open.count))") {
                    ForEach(open) { TodoRow(item: $0) }
                }
                if showDone && !done.isEmpty {
                    Section("Terminées (\(done.count))") {
                        ForEach(done) { TodoRow(item: $0) }
                    }
                }
            }
        }
    }

    private func add() {
        let t = newText.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        store.addTodo(t)
        newText = ""
    }
}

struct TodoRow: View {
    let item: TodoItem
    @ObservedObject private var store = Store.shared
    @State private var editing = false
    @State private var draft = ""

    var body: some View {
        HStack {
            Toggle("", isOn: Binding(get: { item.done }, set: { store.setDone(item.id, $0) }))
                .toggleStyle(.checkbox)
                .labelsHidden()
            if editing {
                TextField("", text: $draft)
                    .onSubmit {
                        let t = draft.trimmingCharacters(in: .whitespaces)
                        if !t.isEmpty { store.renameTodo(item.id, t) }
                        editing = false
                    }
                    .onExitCommand { editing = false }
            } else {
                Text(item.text)
                    .strikethrough(item.done)
                    .foregroundStyle(item.done ? .secondary : .primary)
                    .onTapGesture(count: 2) { draft = item.text; editing = true }
            }
            Spacer()
        }
        .contextMenu {
            Button("Modifier") { draft = item.text; editing = true }
            Button("Supprimer") { store.deleteTodo(item.id) }
        }
    }
}
