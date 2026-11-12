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

Other launch arguments help when working on one screen: `-page todo` (or `settings`, `template`),
`-showQuickLogAtLaunch YES`, `-theme light` / `-theme dark`, `-AppleLanguages "(en)"`.

## Pull requests

- Keep them focused: one fix or feature per PR.
- Match the existing style (4 spaces in Swift, 2 in JS/CSS, no new dependencies without discussion).
- Make sure `./scripts/build-app.sh` succeeds and describe how you tested the change.
- Notes are user data: any change to how files are read or written needs extra care, and a mention in the PR.

## Releases (maintainers)

Releases are built and signed on the maintainer's Mac, never in CI:

1. Move the `[Unreleased]` notes of `CHANGELOG.md` under a new `## [X.Y.Z] - date` section and push to `main`.
2. Run `scripts/release.sh X.Y.Z`. It builds the app, signs `update.json` with the key in the Keychain,
   tags the commit and publishes the GitHub release.

The signing key is created once with `swift scripts/release-key.swift generate`; its public key is in
`Sources/Daylog/Updater.swift`. Keep a backup of the private key somewhere safe: without it, installed apps can't
be updated anymore.

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE),
and to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
