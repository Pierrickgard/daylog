# Security

Daylog runs locally. It reads and writes Markdown files in the folder you choose, and its only network request is
the update check described below, which you can turn off in Settings.

## Updates

Daylog can update itself, and is designed so that no one but the maintainer can ship an update it accepts,
even with full control of the GitHub repository, its releases or the download servers:

- Each release includes `update.json` (version, download URL, size, SHA-256 of the zip) and `update.json.sig`,
  an Ed25519 signature of that file. The signing key is generated and kept in the maintainer's macOS Keychain.
  It is never stored on GitHub or in CI; releases are built and signed locally with `scripts/release.sh`.
- The app embeds the public key (`Sources/Daylog/Updater.swift`) and checks the signature before even reading the
  manifest. It then requires:
  - a version strictly newer than the installed one (no downgrade to an older release);
  - a download URL from this repository's releases, fetched over HTTPS;
  - a zip whose size and SHA-256 match the signed values;
  - an app inside it with the same bundle identifier, the signed version, and a valid code signature.
- Nothing is installed until you click **Install**. Any failed check stops the update and nothing is changed.

## Hardening

- The UI is local HTML loaded from the app bundle. Its web views refuse to navigate anywhere else, use a strict
  Content Security Policy, and keep no website data. Note content is escaped before display.
- The native bridge only opens `http`/`https` links, and only reads or writes files inside the notes folder.

## Known limitation

Daylog is not signed with an Apple Developer ID or notarized yet. macOS asks for confirmation on first launch, and
privacy permissions (such as Documents access) are tied to the bundle identifier rather than to a developer
certificate.

## Reporting a vulnerability

Please report it privately through
[GitHub's private vulnerability reporting](https://github.com/Pierrickgard/daylog/security/advisories/new),
not in a public issue. You should get an answer within a week. Only the latest release receives fixes.
