# Daylog

A tiny macOS app to log what you do during the day and keep a to-do list, without switching apps.

Press a global shortcut (default **⌃⌥N**), pick **Daily** or **To-do**, type a line, hit **↩**. That's it.
At the end of the day, open Daylog and everything you did is there, one note per day.

Everything is stored as plain Markdown, so you can also read and edit your notes with any editor
(Obsidian, VS Code, iA Writer…), sync them with iCloud Drive or put them in git.

```
~/Documents/Daylog/
├── daily/
│   ├── 2026-11-11.md
│   └── 2026-11-12.md
├── todo.md
└── template-daily.md
```

## Features

- **Quick entry popup** from anywhere with a global shortcut (configurable, no accessibility permission needed).
- **Daily notes**: each entry goes under a section of today's note (`## Section`). New days are created from
  `template-daily.md`; its `## ` headings are the sections offered in the popup.
- **To-do list**: add, check, rename (double-click), delete, clear done items. Stored as `- [ ]` / `- [x]` lines in `todo.md`.
- **History**: browse and edit previous days.
- Lives in the menu bar; the Dock icon only shows while the main window is open.
- Optional launch at login.

The UI is in French for now.

## Keyboard

| Where | Keys | Action |
| --- | --- | --- |
| Anywhere | ⌃⌥N | Open the quick entry popup |
| Popup | ⌘1 / ⌘2 | Daily / To-do |
| Popup | ↩ / esc | Add / close |

## Install

Requires macOS 14+ and the Xcode command line tools (`xcode-select --install`).

```sh
git clone <repo-url> daylog && cd daylog
./scripts/build-app.sh install   # builds and copies Daylog.app to /Applications
open /Applications/Daylog.app
```

`./scripts/build-app.sh` alone only builds `build/Daylog.app`. The app is ad-hoc signed, not notarized.

## Notes

- `todo.md` is rewritten by the app: only `- [ ]` / `- [x]` lines are kept.
- Day files are only created once something is written in them, so empty days don't clutter the history.

## License

MIT
