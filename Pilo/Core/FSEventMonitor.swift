import Foundation
import CoreServices

/// 文件系统事件监听器。包 FSEventStream 的 C API 成 AsyncStream<Event>。
///
/// 关键设计（来自 Phase 4 评审）：
///   - C 回调通过 `FSEventStreamSetDispatchQueue` 跑在我们的 serial queue 上；
///     因此 `handle()` 是单线程，无需互斥；NSLock 只保护 start/stop 与 stream 指针
///   - 路径过滤在 yield 之前完成：`/.git/objects/pack/*.tmp` 之类噪声会淹没 debounce 窗口，
///     `git status` 跑大仓库时尤其严重；但 `/.git/HEAD`、`/.git/refs/`、
///     `/.git/packed-refs`、`/.git/MERGE_HEAD` 是真正的分支状态变化，必须保留
///   - 处理 `MustScanSubDirs` / `RootChanged` flag：FSEvents 在内核 buffer 溢出 / disk sleep
///     时会标记这些，意味着事件可能丢失，调用方需要触发全量重扫
final class FSEventMonitor: @unchecked Sendable {

    struct Event: Sendable {
        let path: String
        let flags: UInt32

        var requiresFullRescan: Bool {
            let mask = UInt32(kFSEventStreamEventFlagMustScanSubDirs)
                     | UInt32(kFSEventStreamEventFlagRootChanged)
                     | UInt32(kFSEventStreamEventFlagKernelDropped)
                     | UInt32(kFSEventStreamEventFlagUserDropped)
            return (flags & mask) != 0
        }
    }

    let events: AsyncStream<Event>
    private let continuation: AsyncStream<Event>.Continuation

    private let queue = DispatchQueue(label: "dev.pilo.fsevents", qos: .utility)
    private let lock = NSLock()
    private var stream: FSEventStreamRef?

    init() {
        var cont: AsyncStream<Event>.Continuation!
        self.events = AsyncStream(bufferingPolicy: .bufferingNewest(2048)) { c in
            cont = c
        }
        self.continuation = cont
    }

    deinit {
        stopUnsafe()
        continuation.finish()
    }

    // MARK: - 控制

    func start(paths: [URL]) {
        lock.lock(); defer { lock.unlock() }
        stopUnsafe()
        guard !paths.isEmpty else { return }

        let cfPaths = paths.map(\.path) as CFArray

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        // 必须设 UseCFTypes，回调里的 `eventPaths` 才会是 CFArray<CFString>。
        // 不设的话它是 char**，把它当 NSArray 用会立即 EXC_BAD_ACCESS（v0.1 第一次 ship 翻车在此）。
        let createFlags = UInt32(
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer |
            kFSEventStreamCreateFlagIgnoreSelf |
            kFSEventStreamCreateFlagUseCFTypes
        )

        let callback: FSEventStreamCallback = { _, contextInfo, numEvents, eventPaths, eventFlags, _ in
            guard let contextInfo = contextInfo else { return }
            let monitor = Unmanaged<FSEventMonitor>.fromOpaque(contextInfo).takeUnretainedValue()
            // 与 UseCFTypes 配对：eventPaths 是 CFArrayRef，toll-free bridge 到 NSArray<NSString>
            let cfArray = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue()
            let pathsArr = cfArray as NSArray
            for i in 0..<numEvents {
                guard let path = pathsArr[i] as? String else { continue }
                let flag = eventFlags[i]
                monitor.handle(path: path, flags: flag)
            }
        }

        guard let newStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            cfPaths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            createFlags
        ) else { return }

        FSEventStreamSetDispatchQueue(newStream, queue)
        FSEventStreamStart(newStream)
        self.stream = newStream
    }

    func stop() {
        lock.lock(); defer { lock.unlock() }
        stopUnsafe()
    }

    private func stopUnsafe() {
        guard let s = stream else { return }
        FSEventStreamStop(s)
        FSEventStreamInvalidate(s)
        FSEventStreamRelease(s)
        stream = nil
    }

    // MARK: - 回调（在 self.queue 上单线程执行）

    private func handle(path: String, flags: FSEventStreamEventFlags) {
        // Drop forbidden patterns（除显式保留项外，丢掉所有 /.git/ 路径）
        if path.range(of: "/.git/") != nil {
            if !Self.isAllowedGitInternal(path: path) {
                return
            }
        }
        // Drop 常见 build / cache 噪声
        if Self.hasNoisyPrefix(path: path) {
            return
        }
        continuation.yield(Event(path: path, flags: flags))
    }

    // MARK: - 过滤规则

    private static let allowedGitSuffixes = ["/.git/HEAD", "/.git/MERGE_HEAD", "/.git/packed-refs"]

    private static func isAllowedGitInternal(path: String) -> Bool {
        for suffix in allowedGitSuffixes where path.hasSuffix(suffix) {
            return true
        }
        if path.range(of: "/.git/refs/") != nil { return true }
        return false
    }

    private static let noisyDirSegments: [String] = [
        "/node_modules/", "/vendor/", "/.build/", "/Pods/", "/DerivedData/",
        "/.next/", "/.nuxt/", "/dist/", "/build/", "/out/", "/target/",
        "/.venv/", "/venv/", "/__pycache__/", "/.tox/",
    ]

    private static func hasNoisyPrefix(path: String) -> Bool {
        for seg in noisyDirSegments where path.contains(seg) { return true }
        return false
    }
}
