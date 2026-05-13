import AppKit

/// 邮局音效定义 + 集中播放。
///
/// **设计原则**：
///   - 默认 OFF（跟 Bear/Things/Reeder 等 productivity app 一样静音是 macOS 惯例）
///   - 仅在 4 个高 ROI 场景播放：push 成功 / 每日信件投递 / 新版推送 / 蜡封信打开
///   - 不放 hover / 选中 / 按钮 click 等高频事件（会变成 Slack 综合症）
///   - **不**重复 commit 通知音 —— `UNUserNotificationCenter` 已经通过系统通知音播了一次
///   - 音量由系统全局音量控制；尊重系统静音
///
/// **资产替换路径**：v1 用 macOS 系统音占位；想换成真 postal 音（鸽叫 / 邮戳 / 蜡封）：
///   1. 把 `.caf` 文件放到 `Pilo/Resources/Sounds/<rawValue>.caf`
///   2. 重 build，loader 自动优先 bundle 内的 custom 文件
///   3. 找不到 custom 就 fallback 到 systemSoundName
enum PiloSounds: String, CaseIterable, Sendable {
    /// 推送启程 —— 「信件起飞」。`.running` 状态进入时触发（用户已点最终推送）
    /// 跟 FlyingPiloAnimation（鸽子真起飞）同步
    case pushInFlight
    /// 推送抵达 —— 「信件到了」。`.completed(success)` 时触发
    case pushSuccess
    /// 每日 18:00 信件投递 —— 「邮局魔法瞬间」
    case letterArrived
    /// 「新版已发车」推送到达 —— 「柜台铃叮」
    case updateArrived
    /// 打开 release/update 蜡封信 —— 「蜡封 crack」
    case waxSealCrack

    /// v1 占位：macOS 系统内置音
    /// 路径 `/System/Library/Sounds/<name>.aiff` —— 每台 Mac 都有
    var systemSoundName: String {
        switch self {
        case .pushInFlight:  return "Funk"       // 合成 whoosh —— 接近"起飞"
        case .pushSuccess:   return "Blow"       // 气流 whoosh —— 接近"抵达"
        case .letterArrived: return "Glass"      // 清亮 ping —— 接近"邮件到达"
        case .updateArrived: return "Submarine"  // 声纳 ping —— 接近"柜台铃"
        case .waxSealCrack:  return "Pop"        // 短促 pop —— 接近"封蜡碎"
        }
    }
}

/// 中央播放器。@MainActor 保证 NSSound 调用线程安全 + 状态一致。
@MainActor
final class SoundPlayer {

    /// 用户偏好开关。每次 UserDefaults 改了由 AppState 同步
    var enabled: Bool = false

    /// 预加载 cache —— 启动时 init 一次，避免首次播放有 latency
    private var cache: [PiloSounds: NSSound] = [:]

    init() {
        preload()
    }

    /// 预加载所有音效到 cache
    private func preload() {
        for kind in PiloSounds.allCases {
            cache[kind] = loadSound(for: kind)
        }
    }

    /// 加载逻辑：先看 bundle 内有没有同名 `.caf`（用户的真 postal 资产），
    /// 否则用 systemSoundName（v1 占位）。
    private func loadSound(for kind: PiloSounds) -> NSSound? {
        // 1. Custom .caf in Pilo/Resources/Sounds/
        if let url = Bundle.main.url(
            forResource: kind.rawValue,
            withExtension: "caf",
            subdirectory: "Sounds"
        ), let sound = NSSound(contentsOf: url, byReference: false) {
            return sound
        }
        // 2. Bundle root（不在 Sounds 子目录里也找一下）
        if let url = Bundle.main.url(forResource: kind.rawValue, withExtension: "caf"),
           let sound = NSSound(contentsOf: url, byReference: false) {
            return sound
        }
        // 3. Fallback 到 macOS 系统音
        return NSSound(named: kind.systemSoundName)
    }

    /// 播放音效。enabled = false 时 no-op。
    /// 同一个声音连续 play 不叠加 —— 先 stop 再 play（debounce 视觉级别 ≥ 200ms 由 caller 控）
    func play(_ kind: PiloSounds) {
        guard enabled else { return }
        guard let sound = cache[kind] else { return }
        sound.stop()
        _ = sound.play()
    }
}
