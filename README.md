# Daylog

A tiny macOS app to log what you do during the day, and keep a to-do list, without leaving what you're working on.

Press a global shortcut (default **⌃⌥N**, that is Control + Option + N) from any app, pick **Daily** or **To-do**,
type one line and hit **Return**. At the end of the day, open Daylog: everything you did is there, one note per day,
sorted by section.

Your notes are plain Markdown files in a folder you choose, so you can also read them with any editor
(Obsidian, VS Code, iA Writer…), sync them with iCloud Drive or keep them in git.

```
~/Documents/Daylog/
├── daily/
│   ├── 2026-11-11.md
│   └── 2026-11-12.md
├── todo.md
└── template-daily.md
```

## Features

- **Quick log popup** from anywhere, with a configurable global shortcut (no accessibility permission needed).
- **Daily notes**: each entry goes under a section of today's note. New days start from `template-daily.md`;
  its `## ` headings are the sections offered in the popup, so you organise your days the way you want
  (projects, clients, apps…).
- **To-do list**: add, check, edit (double-click), delete, clear done items. Stored as `- [ ]` / `- [x]` lines in `todo.md`.
- **History**: browse and edit previous days, or edit the raw Markdown of any day.
- Light and dark themes, following the system. English and French.
- Native and light: a small Swift app with a web-based UI (WKWebView), no Electron.

## Keyboard

| Where | Keys | Action |
| --- | --- | --- |
| Anywhere | ⌃⌥N | Open the quick log (change it in Settings) |
| Quick log | ⌘1 / ⌘2 | Daily / To-do |
| Quick log | Tab / Shift-Tab | Next / previous section |
| Quick log | Return / Esc | Add / close |
| Main window | ⌘1 / ⌘2 / ⌘, | Today / To-do / Settings |

## Install

Download `Daylog.zip` from the [latest release](../../releases/latest), unzip it and move `Daylog.app` to `/Applications`.

The app is not notarized by Apple, so the first launch is blocked. Right-click the app → **Open**, or run:

```sh
xattr -dr com.apple.quarantine /Applications/Daylog.app
```

## Build from source

Requires macOS 14+ and the Xcode command line tools (`xcode-select --install`).

```sh
git clone https://github.com/<you>/daylog.git && cd daylog
./scripts/build-app.sh install   # builds build/Daylog.app and copies it to /Applications
```

`swift run` also works for development: the UI is then loaded straight from `Web/`.

## How it's built

```
Sources/Daylog/   Swift: app lifecycle, global shortcut, windows, Markdown storage
  Store.swift       reads and writes the Markdown files
  Bridge.swift      the API the web UI calls (window.webkit.messageHandlers.daylog)
  Windows.swift     main window and quick log panel
Web/              the UI: plain HTML, CSS and JavaScript, no build step
  index.html, app.js     main window
  quick.html, quick.js   quick log popup
  common.js              bridge helper, translations
scripts/          app bundle and icon
```

Contributions are welcome: open an issue first for anything bigger than a fix.

## Notes

- `todo.md` is rewritten by the app: only `- [ ]` / `- [x]` lines are kept.
- A day file is only created once something is written in it, so empty days don't show up in the history.

## License

MIT. Fonts: IBM Plex, SIL Open Font License (`Web/fonts/LICENSE-OFL.txt`).
