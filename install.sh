#!/bin/bash
# NowPlaying Widget 설치 스크립트
#   curl -fsSL https://raw.githubusercontent.com/uuuhyun/nowplaying-widget/main/install.sh | bash
set -euo pipefail

REPO="uuuhyun/nowplaying-widget"
LABEL="io.github.uuuhyun.nowplaying-widget"
APP_DIR="$HOME/Applications"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"

if ! xcode-select -p >/dev/null 2>&1; then
  echo "❌ Xcode Command Line Tools가 필요합니다. 먼저 아래를 실행한 뒤 다시 설치해 주세요."
  echo "   Command Line Tools are required. Run this first, then retry:"
  echo
  echo "   xcode-select --install"
  exit 1
fi

# 레포 안에서 실행하면 로컬 소스, curl로 실행하면 GitHub에서 소스를 받는다
SRC="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ ! -f "$SRC/NowPlaying.swift" ]; then
  SRC="$(mktemp -d)"
  trap 'rm -rf "$SRC"' EXIT
  echo "⬇️  소스 다운로드 중… / Downloading source…"
  curl -fsSL "https://github.com/$REPO/archive/refs/heads/main.tar.gz" | tar -xz -C "$SRC" --strip-components=1
fi

echo "🔨 빌드 중… / Building…"
BUILT="$(bash "$SRC/scripts/build-app.sh" "$SRC/build")"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -x NowPlaying 2>/dev/null || true
mkdir -p "$APP_DIR"
rm -rf "$APP_DIR/NowPlaying.app"
cp -R "$BUILT" "$APP_DIR/"

# 로그인 시 자동 실행 (Music이 켜져 있을 때만 위젯이 보임). 비정상 종료 시에만 재시작
mkdir -p "$(dirname "$AGENT")"
cat > "$AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$APP_DIR/NowPlaying.app/Contents/MacOS/NowPlaying</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>LimitLoadToSessionType</key><string>Aqua</string>
</dict>
</plist>
PLIST
sleep 1
launchctl bootstrap "gui/$(id -u)" "$AGENT"

echo "✅ 설치 완료! Music 앱을 켜면 우상단에 위젯이 나타납니다."
echo "   Installed! The widget appears when Music is running."
echo "   처음 한 번 'Music 제어' 권한 창이 뜨면 허용해 주세요. / Allow the Music automation prompt once."
