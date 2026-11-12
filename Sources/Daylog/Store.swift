import Foundation

/// Everything lives in plain Markdown files inside one folder:
///
///     <folder>/daily/2026-11-12.md   one file per day
///     <folder>/todo.md               the to-do list
///     <folder>/template-daily.md     template for new days ({{date}} is replaced)
///
/// The `## ` headings of the template are the sections offered by the quick entry.
struct TodoItem: Identifiable, Equatable {
    let id = UUID().uuidString
    var text: String
    var done: Bool
}

final class Store {
    static let shared = Store()

    private(set) var dayKeys: [String] = []
    private(set) var todos: [TodoItem] = []

    static let defaultTemplate = L10n.t("""
    # {{date}}

    ## Work

    ## Meetings

    ## Other

    """, """
    # {{date}}

    ## Travail

    ## Réunions

    ## Divers

    """)

    private let fm = FileManager.default

    private let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func formatter(_ template: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = L10n.locale
        f.setLocalizedDateFormatFromTemplate(template)
        return f
    }

    // MARK: Paths

    var folder: URL {
        URL(fileURLWithPath: (Preferences.folderPath as NSString).expandingTildeInPath, isDirectory: true)
    }
    var dailyFolder: URL { folder.appendingPathComponent("daily", isDirectory: true) }
    var todoURL: URL { folder.appendingPathComponent("todo.md") }
    var templateURL: URL { folder.appendingPathComponent("template-daily.md") }

    func dayURL(_ key: String) -> URL { dailyFolder.appendingPathComponent("\(key).md") }

    var todayKey: String { keyFormatter.string(from: Date()) }

    // MARK: Loading

    func bootstrap() {
        try? fm.createDirectory(at: dailyFolder, withIntermediateDirectories: true)
        if !fm.fileExists(atPath: templateURL.path) { write(Self.defaultTemplate, to: templateURL) }
        if !fm.fileExists(atPath: todoURL.path) { write("# To-do\n\n", to: todoURL) }
        reload()
    }

    func reload() {
        reloadDays()
        todos = Self.parseTodos(read(todoURL))
    }

    private func reloadDays() {
        let names = (try? fm.contentsOfDirectory(atPath: dailyFolder.path)) ?? []
        dayKeys = names
            .filter { $0.hasSuffix(".md") }
            .map { String($0.dropLast(3)) }
            .filter { keyFormatter.date(from: $0) != nil }
            .sorted(by: >)
    }

    func read(_ url: URL) -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    func write(_ text: String, to url: URL) {
        let isNewDay = url.deletingLastPathComponent().standardizedFileURL == dailyFolder.standardizedFileURL
            && !fm.fileExists(atPath: url.path)
        try? text.write(to: url, atomically: true, encoding: .utf8)
        if isNewDay { reloadDays() }
    }

    // MARK: Days

    /// "Thursday, November 12, 2026" / "Jeudi 12 novembre 2026"
    func title(for key: String) -> String {
        guard let date = keyFormatter.date(from: key) else { return key }
        return formatter("EEEEdMMMMyyyy").string(from: date).capitalizedFirst
    }

    /// "Thu, Nov 12" / "Jeu. 12 nov." (year added when it is not the current one)
    func shortTitle(for key: String) -> String {
        guard let date = keyFormatter.date(from: key) else { return key }
        let sameYear = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
        return formatter(sameYear ? "EEEdMMM" : "EEEdMMMyyyy").string(from: date).capitalizedFirst
    }

    var sections: [String] {
        read(templateURL)
            .components(separatedBy: "\n")
            .filter { $0.hasPrefix("## ") }
            .map { $0.dropFirst(3).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// What a day file contains before anything is written to it.
    func newDayContent(_ key: String) -> String {
        let date = title(for: key)
        let template = fm.fileExists(atPath: templateURL.path) ? read(templateURL) : Self.defaultTemplate
        return template.replacingOccurrences(of: "{{date}}", with: date)
    }

    @discardableResult
    func ensureDay(_ key: String) -> URL {
        let url = dayURL(key)
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: dailyFolder, withIntermediateDirectories: true)
            write(newDayContent(key), to: url)
        }
        return url
    }

    func addLog(_ entry: String, section: String, day: String? = nil) {
        let url = ensureDay(day ?? todayKey)
        write(Self.insert(entry, under: section, in: read(url)), to: url)
    }

    /// Adds "- entry" at the end of the `## section` block, creating the section if needed.
    static func insert(_ entry: String, under section: String, in text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        let target = section.trimmingCharacters(in: .whitespaces).lowercased()
        let isHeading: (String) -> Bool = { $0.hasPrefix("# ") || $0.hasPrefix("## ") }

        guard let heading = lines.firstIndex(where: {
            $0.hasPrefix("## ") && $0.dropFirst(3).trimmingCharacters(in: .whitespaces).lowercased() == target
        }) else {
            var out = text
            while out.hasSuffix("\n\n") { out.removeLast() }
            if !out.isEmpty && !out.hasSuffix("\n") { out += "\n" }
            return out + "\n## \(section)\n- \(entry)\n"
        }

        let end = lines[(heading + 1)...].firstIndex(where: isHeading) ?? lines.count
        var last = heading
        for i in (heading + 1)..<end where !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
            last = i
        }
        lines.insert("- \(entry)", at: last + 1)
        if last + 1 == end && end + 1 < lines.count {
            lines.insert("", at: end + 1) // keep a blank line before the next heading
        }
        return lines.joined(separator: "\n")
    }

    // MARK: To-do

    var openTodoCount: Int { todos.filter { !$0.done }.count }

    static func parseTodos(_ text: String) -> [TodoItem] {
        text.components(separatedBy: "\n").compactMap { line in
            let l = line.trimmingCharacters(in: .whitespaces)
            if l.hasPrefix("- [ ] ") { return TodoItem(text: String(l.dropFirst(6)), done: false) }
            if l.lowercased().hasPrefix("- [x] ") { return TodoItem(text: String(l.dropFirst(6)), done: true) }
            return nil
        }
    }

    private func saveTodos() {
        let body = todos.map { "- [\($0.done ? "x" : " ")] \($0.text)" }.joined(separator: "\n")
        write("# To-do\n\n" + body + (body.isEmpty ? "" : "\n"), to: todoURL)
    }

    func addTodo(_ text: String) {
        let firstDone = todos.firstIndex(where: \.done) ?? todos.count
        todos.insert(TodoItem(text: text, done: false), at: firstDone)
        saveTodos()
    }

    func setDone(_ id: String, _ done: Bool) {
        guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
        var item = todos.remove(at: i)
        item.done = done
        // open items first, done items after: lands at the end of the open ones
        // or at the top of the done ones
        let firstDone = todos.firstIndex(where: \.done) ?? todos.count
        todos.insert(item, at: firstDone)
        saveTodos()
    }

    func renameTodo(_ id: String, _ text: String) {
        guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[i].text = text
        saveTodos()
    }

    func deleteTodo(_ id: String) {
        todos.removeAll { $0.id == id }
        saveTodos()
    }

    func clearDone() {
        todos.removeAll(where: \.done)
        saveTodos()
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
