#!/bin/sh
# Publishes a signed release from this Mac:  scripts/release.sh 0.2.0
#
# The update manifest is signed here with the key in the login Keychain (scripts/release-key.swift),
# so nothing on GitHub can produce an update that installed apps accept.
set -e
cd "$(dirname "$0")/.."

VERSION="$1"
[ -n "$VERSION" ] || { echo "usage: scripts/release.sh X.Y.Z"; exit 1; }
echo "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || { echo "Version must look like 1.2.3"; exit 1; }
[ "$(git branch --show-current)" = main ] || { echo "Release from main."; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "Commit or stash your changes first."; exit 1; }
git fetch -q origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || { echo "main isn't in sync with origin/main."; exit 1; }
grep -q "^## \[$VERSION\]" CHANGELOG.md || { echo "Add a '## [$VERSION]' section to CHANGELOG.md first."; exit 1; }
git rev-parse "v$VERSION" >/dev/null 2>&1 && { echo "Tag v$VERSION already exists."; exit 1; }

PUBLIC_KEY=$(sed -n 's/.*static let publicKey = "\(.*\)".*/\1/p' Sources/Daylog/Updater.swift)
[ "$(swift scripts/release-key.swift public)" = "$PUBLIC_KEY" ] || { echo "Keychain key doesn't match the public key in Updater.swift."; exit 1; }

VERSION="$VERSION" ./scripts/build-app.sh
OUT=build/release
rm -rf "$OUT" && mkdir -p "$OUT"
ditto -c -k --keepParent build/Daylog.app "$OUT/Daylog.zip"

SHA=$(shasum -a 256 "$OUT/Daylog.zip" | cut -d' ' -f1)
SIZE=$(stat -f %z "$OUT/Daylog.zip")
URL="https://github.com/Pierrickgard/daylog/releases/download/v$VERSION/Daylog.zip"
printf '{"version":"%s","url":"%s","sha256":"%s","size":%s}\n' "$VERSION" "$URL" "$SHA" "$SIZE" > "$OUT/update.json"
swift scripts/release-key.swift sign "$OUT/update.json" > "$OUT/update.json.sig"
swift scripts/release-key.swift verify "$OUT/update.json" "$OUT/update.json.sig" "$PUBLIC_KEY"

# Release notes: the CHANGELOG section for this version.
awk -v v="$VERSION" '$0 ~ "^## \\[" v "\\]" {on=1; next} /^## \[/ {on=0} on' CHANGELOG.md > "$OUT/notes.md"

git tag -a "v$VERSION" -m "Daylog $VERSION"
git push -q origin "v$VERSION"
gh release create "v$VERSION" "$OUT/Daylog.zip" "$OUT/update.json" "$OUT/update.json.sig" \
    --title "Daylog $VERSION" --notes-file "$OUT/notes.md"
echo "Released v$VERSION"
