# Contributing to Daylog

Thanks for your interest! Daylog is meant to stay small and simple, so the best contributions are bug fixes,
polish, and features that fit the "log a line, review your day" idea.

## Before you start

- **Bugs**: open an issue with your macOS version, what you did, and what happened.
- **Features**: open an issue first so we can agree on the idea before you spend time on code.
- **Translations**: very welcome. Strings live in `Web/common.js` (UI) and `Sources/Daylog/L10n.swift` (menus).

## Development setup

Requirements: macOS 14+, Xcode command line tools (`xcode-select --install`).

```sh
git clone https://github.com/Pierrickgard/daylog.git
cd daylog
swift run                         # runs the app, UI loaded straight from Web/
./scripts/build-app.sh            # builds build/Daylog.app
./scripts/build-app.sh install    # also copies it to /Applications
```

The UI is plain HTML, CSS and JavaScript in `Web/`, with no build step: edit, then reopen the window.
`Sources/Daylog/Bridge.swift` lists every call the UI can make to the native side.

Tip: to try things without touching your own notes, point the app at a scratch folder:

```sh
.build/debug/Daylog -folderPath /tmp/daylog-test
```

## Pull requests

- Keep them focused: one fix or feature per PR.
- Match the existing style (4 spaces in Swift, 2 in JS/CSS, no new dependencies without discussion).
- Make sure `./scripts/build-app.sh` succeeds and describe how you tested the change.
- Notes are user data: any change to how files are read or written needs extra care, and a mention in the PR.

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE),
and to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
