// NowPlaying Widget — Apple Music 현재 곡(커버+제목)을 항상 위에 띄우는 플로팅 위젯
// https://github.com/uuuhyun/nowplaying-widget
import AppKit
import SwiftUI

// MARK: - 상태

final class PlayerModel: ObservableObject {
    @Published var title = "재생 중인 곡 없음"
    @Published var artist = ""
    @Published var artwork: NSImage?
    @Published var isPlaying = false

    private var lastTrackKey = ""

    /// `--demo` 인자로 실행하면 저작권 걱정 없는 샘플 곡/커버를 띄운다 (스크린샷용)
    static let isDemo = CommandLine.arguments.contains("--demo")

    init() {
        if Self.isDemo {
            title = "Clair de Lune"
            artist = "Claude Debussy"
            artwork = Self.demoArtwork()
            isPlaying = true
            return
        }
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(playerInfoChanged(_:)),
            name: NSNotification.Name("com.apple.Music.playerInfo"), object: nil)
        refresh()
    }

    @objc private func playerInfoChanged(_ note: Notification) {
        let info = note.userInfo ?? [:]
        let state = info["Player State"] as? String ?? ""
        DispatchQueue.main.async {
            if state == "Stopped" {
                self.clear()
                return
            }
            self.isPlaying = (state == "Playing")
            if let name = info["Name"] as? String { self.title = name }
            self.artist = info["Artist"] as? String ?? ""
            self.updateArtworkIfNeeded()
        }
    }

    /// 앱 시작 시 현재 상태를 한 번 읽어 온다.
    func refresh() {
        if Self.isDemo { return }
        guard Music.isRunning else { clear(); return }
        let script = """
        tell application "Music"
            if player state is stopped then return "STOPPED"
            set s to "PAUSED"
            if player state is playing then set s to "PLAYING"
            return s & linefeed & (name of current track) & linefeed & (artist of current track)
        end tell
        """
        guard let out = Music.run(script)?.stringValue, out != "STOPPED" else { clear(); return }
        let parts = out.components(separatedBy: "\n")
        isPlaying = parts.first == "PLAYING"
        title = parts.count > 1 ? parts[1] : ""
        artist = parts.count > 2 ? parts[2] : ""
        updateArtworkIfNeeded()
    }

    private func updateArtworkIfNeeded() {
        let key = title + "|" + artist
        guard key != lastTrackKey else { return }
        lastTrackKey = key
        // 곡이 바뀐 직후엔 아트워크가 늦게 붙는 경우가 있어 약간 지연 후 조회
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.artwork = Music.currentArtwork()
        }
    }

    private static func demoArtwork() -> NSImage {
        NSImage(size: NSSize(width: 300, height: 300), flipped: false) { rect in
            NSGradient(colors: [NSColor(red: 0.16, green: 0.20, blue: 0.45, alpha: 1),
                                NSColor(red: 0.55, green: 0.36, blue: 0.75, alpha: 1),
                                NSColor(red: 0.98, green: 0.72, blue: 0.55, alpha: 1)])?
                .draw(in: rect, angle: -60)
            // 달
            NSColor(white: 1, alpha: 0.9).setFill()
            NSBezierPath(ovalIn: NSRect(x: 175, y: 175, width: 70, height: 70)).fill()
            if let note = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 110, weight: .semibold)) {
                let tinted = NSImage(size: note.size, flipped: false) { r in
                    note.draw(in: r); NSColor(white: 1, alpha: 0.85).set(); r.fill(using: .sourceAtop); return true
                }
                tinted.draw(in: NSRect(x: 45, y: 40, width: tinted.size.width, height: tinted.size.height))
            }
            return true
        }
    }

    private func clear() {
        title = "재생 중인 곡 없음"
        artist = ""
        artwork = nil
        isPlaying = false
        lastTrackKey = ""
    }
}

enum Music {
    static var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty
    }

    @discardableResult
    static func run(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error { NSLog("NowPlaying AppleScript error: \(error)") }
        return result
    }

    static func currentArtwork() -> NSImage? {
        guard isRunning else { return nil }
        for prop in ["raw data", "data"] {
            let script = """
            tell application "Music"
                if (count of artworks of current track) is 0 then return missing value
                return \(prop) of artwork 1 of current track
            end tell
            """
            if let data = run(script)?.data, let image = NSImage(data: data) { return image }
        }
        return nil
    }

    static func playPause() { if isRunning { run(#"tell application "Music" to playpause"#) } }
    static func next() { if isRunning { run(#"tell application "Music" to next track"#) } }
    static func previous() { if isRunning { run(#"tell application "Music" to previous track"#) } }
}

// MARK: - 설정

final class Settings: ObservableObject {
    @AppStorage("artSize") var artSize: Double = 64 { willSet { objectWillChange.send() } }
    @AppStorage("opacity") var opacity: Double = 1.0 { willSet { objectWillChange.send() } }
}

// MARK: - 뷰

struct NowPlayingView: View {
    @ObservedObject var model: PlayerModel
    @ObservedObject var settings: Settings
    var actions: PanelActions

    var body: some View {
        HStack(spacing: 12) {
            artworkView
                .frame(width: settings.artSize, height: settings.artSize)
                .clipShape(RoundedRectangle(cornerRadius: settings.artSize * 0.12, style: .continuous))
                .shadow(radius: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(model.title)
                    .font(.system(size: 13 + settings.artSize / 32, weight: .semibold))
                    .lineLimit(1)
                    .padding(.trailing, 22)   // ✕ 버튼 자리
                if !model.artist.isEmpty {
                    Text(model.artist)
                        .font(.system(size: 11 + settings.artSize / 40))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 14) {
                    ControlButton(symbol: "backward.fill", help: "이전 곡") { Music.previous() }
                    ControlButton(symbol: model.isPlaying ? "pause.fill" : "play.fill",
                                  help: model.isPlaying ? "일시정지" : "재생", size: 15) { Music.playPause() }
                    ControlButton(symbol: "forward.fill", help: "다음 곡") { Music.next() }
                    Spacer(minLength: 0)
                    ControlButton(symbol: "scope", help: "기본 위치로") { actions.resetPosition() }
                }
                .padding(.top, 2)
            }
            .frame(width: 140 + settings.artSize * 1.5, alignment: .leading)
        }
        .padding(10)
        .overlay(alignment: .topTrailing) {
            ControlButton(symbol: "xmark", help: "숨기기 (Music을 다시 켜면 나타남)", size: 12) { actions.hide() }
                .padding(.top, 4)
                .padding(.trailing, 10)
        }
        .background(VisualEffect().clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)))
        .opacity(model.isPlaying ? settings.opacity : settings.opacity * 0.75)
        .fixedSize()
        .contextMenu {
            Menu("크기") {
                ForEach([("작게", 44.0), ("보통", 64.0), ("크게", 96.0), ("아주 크게", 140.0)], id: \.1) { item in
                    Button(item.0) { settings.artSize = item.1 }
                }
            }
            Menu("투명도") {
                ForEach([100, 85, 70, 50], id: \.self) { pct in
                    Button("\(pct)%") { settings.opacity = Double(pct) / 100 }
                }
            }
            Button("새로고침") { model.refresh() }
            Divider()
            Button("종료") { NSApp.terminate(nil) }
        }
    }

    @ViewBuilder private var artworkView: some View {
        if let art = model.artwork {
            Image(nsImage: art).resizable().aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Color.gray.opacity(0.3)
                Image(systemName: "music.note").font(.system(size: settings.artSize * 0.4))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ControlButton: View {
    let symbol: String
    let help: String
    var size: CGFloat = 12
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .frame(width: 22, height: 20)
                .contentShape(Rectangle())
                .foregroundStyle(hovering ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()   // 키 윈도우일 때 파란 포커스 테두리 제거
        .help(help)
        .onHover { hovering = $0 }
    }
}

/// 뷰에서 창 조작을 요청할 때 쓰는 콜백 모음
struct PanelActions {
    var resetPosition: () -> Void
    var hide: () -> Void
}

struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - 창

private extension NSRect {
    var area: CGFloat { isNull ? 0 : width * height }
}

final class FloatingPanel: NSPanel {
    // nonactivating 패널이라 키 윈도우가 돼도 앱이 앞으로 나서지 않는다 (우클릭 메뉴용)
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // 내용(제목·커버 크기)에 따라 창이 커질 때 화면 밖으로 나가지 않게 보정
    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        var f = frameRect
        // 새 프레임과 가장 많이 겹치는 모니터 기준 (멀티 모니터 대응)
        let target = NSScreen.screens.max {
            $0.frame.intersection(frameRect).area < $1.frame.intersection(frameRect).area
        }
        if let vis = (target ?? NSScreen.main)?.visibleFrame {
            f.origin.x = min(max(f.minX, vis.minX), vis.maxX - f.width - 8)
            f.origin.y = min(max(f.minY, vis.minY), vis.maxY - f.height)
        }
        super.setFrame(f, display: flag)
    }
}

/// 비활성 창에서도 첫 클릭이 바로 버튼에 먹도록
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = PlayerModel()
    let settings = Settings()
    var panel: FloatingPanel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let actions = PanelActions(resetPosition: { [weak self] in self?.resetPosition() },
                                   hide: { [weak self] in self?.panel.orderOut(nil) })
        let host = FirstClickHostingView(rootView: NowPlayingView(model: model, settings: settings, actions: actions))
        host.sizingOptions = [.intrinsicContentSize]

        panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.level = .floating                       // 항상 다른 창 위
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true      // 드래그로 이동
        panel.hidesOnDeactivate = false
        panel.contentView = host

        if panel.setFrameUsingName("NowPlayingPanel") {
            // 저장된 위치의 좌상단은 유지하고 크기만 내용에 맞춘다
            let size = host.fittingSize
            let f = panel.frame
            var frame = NSRect(x: f.minX, y: f.maxY - size.height, width: size.width, height: size.height)
            // 크기가 바뀌어 화면 밖으로 나가면 안쪽으로 밀어 넣는다
            if let vis = (panel.screen ?? NSScreen.main)?.visibleFrame {
                frame.origin.x = min(max(frame.minX, vis.minX), vis.maxX - frame.width)
                frame.origin.y = min(max(frame.minY, vis.minY), vis.maxY - frame.height)
            }
            panel.setFrame(frame, display: true)
        } else {
            resetPosition()
        }
        panel.setFrameAutosaveName("NowPlayingPanel")

        // Music 앱이 켜지면 띄우고 꺼지면 숨긴다
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(appLaunched(_:)),
                       name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        ws.addObserver(self, selector: #selector(appTerminated(_:)),
                       name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        if Music.isRunning || PlayerModel.isDemo { panel.orderFrontRegardless() }
    }

    /// 위젯이 있는 모니터의 우상단(메뉴바 바로 아래)으로 이동
    func resetPosition() {
        guard let screen = (panel.screen ?? NSScreen.main)?.visibleFrame else { return }
        let size = panel.contentView?.fittingSize ?? panel.frame.size
        panel.setFrame(NSRect(x: screen.maxX - size.width - 16, y: screen.maxY - size.height - 12,
                              width: size.width, height: size.height), display: true, animate: true)
    }

    private static func isMusic(_ note: Notification) -> Bool {
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        return app?.bundleIdentifier == "com.apple.Music"
    }

    @objc func appLaunched(_ note: Notification) {
        guard Self.isMusic(note) else { return }
        panel.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.model.refresh() }
    }

    @objc func appTerminated(_ note: Notification) {
        guard Self.isMusic(note), !PlayerModel.isDemo else { return }
        panel.orderOut(nil)
        model.refresh()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // Dock 아이콘 없음
app.run()
