# 기여 가이드 / Contributing

NowPlaying Widget에 관심 가져 주셔서 고맙습니다! 버그 제보, 기능 제안, PR 모두 환영합니다.
Thanks for your interest! Bug reports, feature ideas and pull requests are all welcome.

## 개발 환경 / Development

준비물: macOS 14 이상, Command Line Tools (`xcode-select --install`), Apple Music 앱

```bash
git clone https://github.com/<your-id>/nowplaying-widget.git
cd nowplaying-widget
./install.sh        # 빌드 → ~/Applications 설치 → 자동 실행 등록
```

수정한 뒤에는 `./install.sh`를 다시 실행하면 새 빌드로 교체됩니다.
빌드만 확인하고 싶다면 `bash scripts/build-app.sh` (결과물: `build/NowPlaying.app`).

Music 앱 없이 화면만 확인하고 싶다면 데모 모드를 쓰세요.

```bash
build/NowPlaying.app/Contents/MacOS/NowPlaying --demo
```

> 다시 빌드하면 앱 서명이 바뀌어 "Music 제어" 권한 창이 다시 뜰 수 있습니다. 허용하면 됩니다.

## 코드 구조 / Code layout

모든 코드는 [`NowPlaying.swift`](NowPlaying.swift) 한 파일에 있고, `// MARK:`로 구역이 나뉘어 있습니다.

| 구역 | 내용 |
|---|---|
| `상태` | `PlayerModel` — Music의 `com.apple.Music.playerInfo` 알림을 구독해 곡 정보 갱신, `Music` — AppleScript로 아트워크·재생 제어 |
| `설정` | `Settings` — 크기·투명도 (`@AppStorage`) |
| `뷰` | `NowPlayingView`(SwiftUI), 컨트롤 버튼, 우클릭 메뉴 |
| `창` | `FloatingPanel`(항상 위 `NSPanel`), `AppDelegate` — Music 실행/종료에 따라 표시·숨김, 위치 저장 |

그 밖에 `scripts/build-app.sh`(앱 번들 빌드), `install.sh` / `uninstall.sh`(설치·삭제)가 있습니다.

## 지켜 주세요 / Principles

- **가볍게** — 외부 패키지 의존성 없이, 폴링보다 알림 기반으로
- **단일 파일 유지** — 파일이 너무 커지면 분리를 먼저 이슈에서 논의해 주세요
- **Xcode 프로젝트 없이** `swiftc`만으로 빌드되게
- 사용자에게 보이는 문구는 한국어·영어 모두 고려

## 기여 흐름 / Workflow

1. 큰 변경(새 기능, 구조 변경)은 먼저 [이슈](https://github.com/uuuhyun/nowplaying-widget/issues)로 방향을 맞춰 주세요. 오타·작은 버그는 바로 PR 해도 됩니다.
2. Fork → 브랜치 생성 (`feat/spotify-support`, `fix/artwork-missing` 처럼)
3. 변경 후 `bash scripts/build-app.sh`로 빌드가 되는지, 실제로 실행해 동작하는지 확인
4. PR을 열 때 템플릿에 맞춰 무엇을 바꿨는지, 어떻게 확인했는지 적어 주세요. UI 변경이면 스크린샷을 꼭 첨부해 주세요.

PR이 올라오면 GitHub Actions가 macOS에서 빌드를 자동으로 검사합니다.

## 라이선스 / License

기여한 코드는 이 프로젝트의 [MIT 라이선스](LICENSE)로 배포됩니다.
By contributing, you agree that your contributions will be licensed under the MIT License.
