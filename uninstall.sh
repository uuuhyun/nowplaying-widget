#!/bin/bash
# NowPlaying Widget 삭제 스크립트
#   curl -fsSL https://raw.githubusercontent.com/uuuhyun/nowplaying-widget/main/uninstall.sh | bash
LABEL="io.github.uuuhyun.nowplaying-widget"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
pkill -x NowPlaying 2>/dev/null || true
rm -rf "$HOME/Applications/NowPlaying.app"
defaults delete "$LABEL" 2>/dev/null || true
echo "🗑  삭제 완료 / Uninstalled"
