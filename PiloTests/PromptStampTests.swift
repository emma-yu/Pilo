import XCTest
@testable import Pilo

/// PromptStamp 模型 + persistence + 派生逻辑测试
final class PromptStampTests: XCTestCase {

    // MARK: - Codable round-trip

    func testStampCodableRoundTrip() throws {
        let original = PromptStamp(
            title: "重构函数",
            body: "请帮我重构这个函数...",
            emoji: "🔧",
            tint: .blue,
            pinned: true,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            lastUsedAt: Date(timeIntervalSince1970: 1_700_100_000),
            useCount: 5
        )
        let data = try JSONEncoder.pilo.encode(original)
        let decoded = try JSONDecoder.pilo.decode(PromptStamp.self, from: data)
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.title, decoded.title)
        XCTAssertEqual(original.body, decoded.body)
        XCTAssertEqual(original.emoji, decoded.emoji)
        XCTAssertEqual(original.tint, decoded.tint)
        XCTAssertEqual(original.pinned, decoded.pinned)
        XCTAssertEqual(original.useCount, decoded.useCount)
    }

    func testArchiveCodableRoundTrip() throws {
        let archive = PromptStampArchive(
            version: 1,
            stamps: [
                .init(title: "A", body: "a", emoji: "🔧", tint: .blue),
                .init(title: "B", body: "b", emoji: "📖", tint: .gold),
            ]
        )
        let data = try JSONEncoder.pilo.encode(archive)
        let decoded = try JSONDecoder.pilo.decode(PromptStampArchive.self, from: data)
        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.stamps.count, 2)
        XCTAssertEqual(decoded.stamps[0].title, "A")
    }

    func testEmptyArchive() {
        XCTAssertTrue(PromptStampArchive.empty.stamps.isEmpty)
        XCTAssertEqual(PromptStampArchive.empty.version, 1)
    }

    // MARK: - StampTint 6 个颜色都有 color mapping

    func testAllTintsHaveColor() {
        // 守门：新加 tint case 要记得加 color mapping
        for tint in PromptStamp.StampTint.allCases {
            _ = tint.color  // 不 crash 即 OK
        }
        XCTAssertEqual(PromptStamp.StampTint.allCases.count, 6)
    }

    // MARK: - 默认值

    func testDefaultInit() {
        let stamp = PromptStamp(title: "X", body: "Y", emoji: "✨")
        XCTAssertEqual(stamp.tint, .gold)
        XCTAssertFalse(stamp.pinned)
        XCTAssertNil(stamp.lastUsedAt)
        XCTAssertEqual(stamp.useCount, 0)
    }

    // MARK: - Sidebar 派生逻辑（@MainActor AppState API）

    @MainActor
    func testSidebarStampsOnlyPinned() {
        let state = AppState()
        // 注意：AppState init 会从磁盘加载持久化邮票；测试用空 archive 强制覆盖
        state.promptStampArchive = .empty
        state.addPromptStamp(.init(title: "A", body: "a", emoji: "🔧", pinned: true))
        state.addPromptStamp(.init(title: "B", body: "b", emoji: "📖", pinned: false))
        state.addPromptStamp(.init(title: "C", body: "c", emoji: "🐛", pinned: true))
        let pinnedTitles = state.sidebarStamps.map(\.title)
        XCTAssertEqual(Set(pinnedTitles), ["A", "C"])
        XCTAssertFalse(pinnedTitles.contains("B"))

        // 清理 —— 不污染本机持久化文件（保险，AppState 已经存盘）
        state.deletePromptStamp(state.promptStampArchive.stamps[0].id)
        state.deletePromptStamp(state.promptStampArchive.stamps[0].id)
        state.deletePromptStamp(state.promptStampArchive.stamps[0].id)
    }

    @MainActor
    func testSidebarStampsCappedAtFive() {
        let state = AppState()
        state.promptStampArchive = .empty
        // 加 7 个钉住的
        for i in 0..<7 {
            state.addPromptStamp(.init(title: "S\(i)", body: "x", emoji: "✨", pinned: true))
        }
        XCTAssertEqual(state.sidebarStamps.count, 5, "sidebar 上限 5 张")
        XCTAssertEqual(state.totalStampCount, 7)
        XCTAssertEqual(state.sidebarOverflowCount, 2)

        // 清理
        for stamp in state.promptStampArchive.stamps {
            state.deletePromptStamp(stamp.id)
        }
    }

    @MainActor
    func testSidebarStampsSortedByLastUsed() {
        let state = AppState()
        state.promptStampArchive = .empty
        let old = Date().addingTimeInterval(-3600)
        let recent = Date()
        state.addPromptStamp(.init(
            title: "Old", body: "x", emoji: "📜", pinned: true,
            createdAt: Date().addingTimeInterval(-7200),
            lastUsedAt: old, useCount: 1
        ))
        state.addPromptStamp(.init(
            title: "Recent", body: "y", emoji: "✨", pinned: true,
            createdAt: Date().addingTimeInterval(-7200),
            lastUsedAt: recent, useCount: 1
        ))
        XCTAssertEqual(state.sidebarStamps.first?.title, "Recent")

        // 清理
        for stamp in state.promptStampArchive.stamps {
            state.deletePromptStamp(stamp.id)
        }
    }

    @MainActor
    func testPasteUpdatesUseCount() {
        let state = AppState()
        state.promptStampArchive = .empty
        let stamp = PromptStamp(title: "T", body: "p", emoji: "🔧", pinned: true)
        state.addPromptStamp(stamp)

        let initial = state.promptStampArchive.stamps.first!
        XCTAssertEqual(initial.useCount, 0)
        XCTAssertNil(initial.lastUsedAt)

        state.pasteStamp(initial)

        let after = state.promptStampArchive.stamps.first!
        XCTAssertEqual(after.useCount, 1)
        XCTAssertNotNil(after.lastUsedAt)

        // 剪贴板校验
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "p")

        // 清理
        state.deletePromptStamp(after.id)
    }

    @MainActor
    func testTogglePin() {
        let state = AppState()
        state.promptStampArchive = .empty
        let stamp = PromptStamp(title: "T", body: "p", emoji: "🔧", pinned: false)
        state.addPromptStamp(stamp)
        let id = state.promptStampArchive.stamps.first!.id

        XCTAssertFalse(state.promptStampArchive.stamps.first!.pinned)
        state.togglePinStamp(id)
        XCTAssertTrue(state.promptStampArchive.stamps.first!.pinned)
        state.togglePinStamp(id)
        XCTAssertFalse(state.promptStampArchive.stamps.first!.pinned)

        state.deletePromptStamp(id)
    }

    @MainActor
    func testDeleteRemoves() {
        let state = AppState()
        state.promptStampArchive = .empty
        let stamp = PromptStamp(title: "T", body: "p", emoji: "🔧")
        state.addPromptStamp(stamp)
        let id = state.promptStampArchive.stamps.first!.id
        XCTAssertEqual(state.totalStampCount, 1)
        state.deletePromptStamp(id)
        XCTAssertEqual(state.totalStampCount, 0)
    }
}
