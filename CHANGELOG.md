# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Signed automatic updates: daily check, "Update available" in the sidebar, one-click install. Can be turned off.

### Security
- No local paths in the compiled app; release zips carry no extended attributes.
- The update check sends a plain `Daylog` User-Agent (no app or macOS version).
- Web views can only show the app's own pages, with a strict Content Security Policy.
- The bridge only opens http(s) links.

### Changed
- Daylog lives in the menu bar: the Dock icon only shows while the window is open, and ⌘Q closes the window
  without stopping the quick log, and so does "Quit" from the Dock icon. "Quit Daylog Completely" is in the app menu
  and the menu bar icon's menu.
- Theme setting: System, Light or Dark.
- New settings icon, and a menu bar icon matching the app icon.
- History is grouped by month, with the year; older months are collapsed.

## [0.1.0] - 2026-11-12

First public release.

### Added
- Quick log popup opened with a global shortcut (default ⌃⌥N), to add a line to today's note or to the to-do list.
- One Markdown note per day, created from an editable template whose `## ` headings are the sections.
- To-do list stored in `todo.md`: add, check, edit, delete, clear done items.
- History of past days, rendered view and raw Markdown editing.
- Settings: shortcut, notes folder, open at login.
- `daylog://quick`, `daylog://open` and `daylog://settings` links.
- English and French, light and dark themes.

[Unreleased]: https://github.com/Pierrickgard/daylog/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Pierrickgard/daylog/releases/tag/v0.1.0
