#!/bin/bash
# NowPlaying.app 번들을 빌드한다.  사용법: scripts/build-app.sh [출력 폴더(기본: build)]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/build}"
APP="$OUT/NowPlaying.app"
VERSION="$(cat "$ROOT/VERSION" 2>/dev/null || echo 0.0.0)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O "$ROOT/NowPlaying.swift" -o "$APP/Contents/MacOS/NowPlaying"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>io.github.uuuhyun.nowplaying-widget</string>
  <key>CFBundleName</key><string>NowPlaying</string>
  <key>CFBundleExecutable</key><string>NowPlaying</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Shows the current track and album artwork from Music. / 현재 재생 중인 곡 정보와 앨범 커버를 표시하기 위해 Music 앱에 접근합니다.</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null 2>&1
echo "$APP"
