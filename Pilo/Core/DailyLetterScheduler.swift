import Foundation

/// 每日信件投递时机管理。
/// 规则：
///   - 每天 18:00（用户本地 timezone）触发投递
///   - App 启动时检查：今天 ≥ 18:00 但还没今日信件 → 立即补发
///   - 同一天最多 1 封
///   - 今日完全无活动（commit + 草稿都没）→ 不生成信
///   - composer 在 main actor 之外跑（async）；调度器只负责 when，不负责 how
@MainActor
final class DailyLetterScheduler {

    /// 18 = 下午 6 点
    static let deliveryHour = 18

    /// 当前调度的 timer（到下一个 18:00）
    private var deliveryTask: Task<Void, Never>?

    /// 投递 callback：scheduler 触发时 caller 应跑 composer 并 persist
    private let onDeliveryTrigger: @MainActor () async -> Void

    init(onDeliveryTrigger: @escaping @MainActor () async -> Void) {
        self.onDeliveryTrigger = onDeliveryTrigger
    }

    /// 启动调度：
    ///   1. 立即检查"是否该补发今日的信"
    ///   2. 调度到下一个 18:00
    func start() {
        deliveryTask?.cancel()
        deliveryTask = Task { [weak self] in
            // 立即检查补发
            await self?.checkAndMaybeDeliverNow()
            // 调度到下一个 18:00 循环
            await self?.runDailyLoop()
        }
    }

    func stop() {
        deliveryTask?.cancel()
        deliveryTask = nil
    }

    /// 立即检查：如果今天 ≥ 18:00 且 archive 里没今天的信 → 触发投递
    private func checkAndMaybeDeliverNow() async {
        let now = Date()
        if Self.shouldDeliverImmediately(now: now, archive: LetterStore.load()) {
            await onDeliveryTrigger()
        }
    }

    /// 循环：算到下一个 18:00 的秒数，sleep，触发，再循环
    private func runDailyLoop() async {
        while !Task.isCancelled {
            let now = Date()
            let next = Self.nextDeliveryTime(after: now)
            let interval = next.timeIntervalSince(now)
            // Task.sleep 跨过 timezone change 不会 drift —— 每次都重新算 next
            try? await Task.sleep(nanoseconds: UInt64(max(60, interval) * 1_000_000_000))
            if Task.isCancelled { break }
            // 到点了
            await onDeliveryTrigger()
        }
    }

    // MARK: - 时间计算

    /// 给定 now，下一个 18:00 是什么时候。
    /// - 如果今天 < 18:00 → 今天 18:00
    /// - 如果今天 ≥ 18:00 → 明天 18:00
    static func nextDeliveryTime(after now: Date) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = deliveryHour
        comps.minute = 0
        comps.second = 0
        let todayDelivery = cal.date(from: comps) ?? now
        if now < todayDelivery {
            return todayDelivery
        }
        return cal.date(byAdding: .day, value: 1, to: todayDelivery) ?? todayDelivery
    }

    /// 启动时判断：是不是应该立即投递（而不是等下一个 18:00）。
    /// 条件：当前时间 ≥ 今天 18:00 AND archive 里没今天的信。
    static func shouldDeliverImmediately(now: Date, archive: LetterArchive) -> Bool {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = deliveryHour
        comps.minute = 0
        comps.second = 0
        guard let todayDelivery = cal.date(from: comps), now >= todayDelivery else {
            return false
        }
        return archive.letter(forDate: now) == nil
    }
}
