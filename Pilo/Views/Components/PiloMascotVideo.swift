import SwiftUI
import AVFoundation

/// 视频版 Pilo mascot —— 仅供 Onboarding hero（Welcome / Complete）使用。
///
/// 视频源是 720×720 macOS squircle app icon 形状的 H.264：蓝底 + 白鸽 + 信封 +
/// ❤️。720×720 帧的 4 个尖角是纯黑（squircle 外面）。这里用 layer `cornerRadius`
/// + `cornerCurve = .continuous` 同款 Apple squircle 数学把 4 个黑角裁掉。
///
/// 降级：`accessibilityReduceMotion` 开启时 → 静态 `PiloMascot(.happy)`。
struct PiloMascotVideo: View {

    var size: CGFloat = 120

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            PiloMascot(mood: .happy, size: size, breathing: false)
        } else {
            PiloMascotPlayerView(size: size)
                .frame(width: size, height: size)
                .accessibilityHidden(true)  // 周围有 hero 文案承担 a11y
        }
    }
}

// MARK: - AVPlayer-backed NSViewRepresentable

private struct PiloMascotPlayerView: NSViewRepresentable {
    let size: CGFloat

    func makeNSView(context: Context) -> PiloMascotPlayerNSView {
        let view = PiloMascotPlayerNSView()
        view.configure(cornerRadiusFactor: 0.22)
        view.startPlayback()
        return view
    }

    func updateNSView(_ nsView: PiloMascotPlayerNSView, context: Context) {
        // size 通过外层 .frame 控制；这里无需更新
    }

    static func dismantleNSView(_ nsView: PiloMascotPlayerNSView, coordinator: ()) {
        nsView.teardown()
    }
}

private final class PiloMascotPlayerNSView: NSView {

    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var playerLayer: AVPlayerLayer?
    private var cornerRadiusFactor: CGFloat = 0.22

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        if let l = layer {
            // 首帧加载前先铺 PiloBlue 底色，避免黑闪
            l.backgroundColor = NSColor(named: "PiloBlue")?.cgColor
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(cornerRadiusFactor: CGFloat) {
        self.cornerRadiusFactor = cornerRadiusFactor
        guard let l = layer else { return }
        l.cornerRadius = bounds.width * cornerRadiusFactor
        l.cornerCurve = .continuous
        l.masksToBounds = true
    }

    func startPlayback() {
        guard playerLayer == nil,
              let url = Bundle.main.url(forResource: "pilo-mascot", withExtension: "mp4")
        else { return }

        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer(playerItem: item)
        queue.isMuted = true
        queue.preventsDisplaySleepDuringVideoPlayback = false
        let looper = AVPlayerLooper(player: queue, templateItem: item)

        let pl = AVPlayerLayer(player: queue)
        pl.videoGravity = .resizeAspectFill
        pl.frame = bounds
        layer?.addSublayer(pl)

        self.player = queue
        self.looper = looper
        self.playerLayer = pl

        queue.play()
    }

    override func layout() {
        super.layout()
        playerLayer?.frame = bounds
        layer?.cornerRadius = bounds.width * cornerRadiusFactor
    }

    func teardown() {
        player?.pause()
        looper = nil
        player = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
    }
}
