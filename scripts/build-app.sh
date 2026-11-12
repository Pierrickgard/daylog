#!/bin/sh
# Builds build/Daylog.app (release, ad-hoc signed). `scripts/build-app.sh install` also copies it to /Applications.
set -e
cd "$(dirname "$0")/.."

VERSION=${VERSION:-0.1.0}
APP=build/Daylog.app

# Map the checkout path to "." so no local path (user name, folders) ends up in the binary.
swift build -c release -Xswiftc -file-prefix-map -Xswiftc "$PWD=."
mkdir -p build
[ -f build/AppIcon.icns ] || swift scripts/make-icon.swift build/AppIcon.icns

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Daylog "$APP/Contents/MacOS/Daylog"
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -R Web "$APP/Contents/Resources/web"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Daylog</string>
    <key>CFBundleDisplayName</key><string>Daylog</string>
    <key>CFBundleIdentifier</key><string>io.github.daylog</string>
    <key>CFBundleExecutable</key><string>Daylog</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
        <key>NSHighResolutionCapable</key><true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key><string>io.github.daylog</string>
            <key>CFBundleURLSchemes</key><array><string>daylog</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST
# A fixed designated requirement keeps macOS privacy permissions (e.g. Documents access) across rebuilds.
codesign --force --sign - -r '=designated => identifier "io.github.daylog"' "$APP"
echo "Built $APP"

if [ "$1" = "install" ]; then
    pkill -x Daylog 2>/dev/null || true
    rm -rf /Applications/Daylog.app
    cp -R "$APP" /Applications/
    echo "Installed /Applications/Daylog.app"
fi
