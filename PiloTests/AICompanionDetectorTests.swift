import XCTest
@testable import Pilo

/// Phase 2 · AICompanionDetector + DailyLetter aiCompanions 字段
///
/// **隐私边界守门**：detector 只能用 mtime / dirname，**不能读文件内容**。
/// 这些测试用 temp dir 模拟 AI 工具数据目录（不依赖用户机器的真实 ~/.claude 等）。
///
/// 注意：当前 detector 写死了真实 home 目录路径，所以这里测的是用户能复现的层面：
///   1. DailyLetter Codable 向后兼容（旧 letters.json 没 aiCompanions 仍能 decode）
///   2. AICompanionSummary 模型自身 round-trip
///   3. detectActivity 在缺少所有 AI 数据目录时返回 [] 不 crash
///   4. Aider repo 检测（这个走 repos 参数，可控）
final class AICompanionDetectorTests: XCTestCase {

    // MARK: - DailyLetter Codable backward-compat

    func testDailyLetterDecodesWithoutAICompanions() throws {
        // 模拟旧 letters.json：先用 old struct shape encode（即不带 aiCompanions 字段）
        // → decode 成新 DailyLetter（应 fallback aiCompanions=nil）
        struct OldLetter: Encodable {
            let id: UUID
            let date: Date
            let deliveredAt: Date
            let repoSummaries: [DailyLetter.RepoSummary]
            let draftRepos: [DailyLetter.DraftSummary]
            let totalCommits: Int
            let activeRepoCount: Int
        }
        let old = OldLetter(
            id: UUID(),
            date: Date(timeIntervalSince1970: 1_700_000_000),
            deliveredAt: Date(timeIntervalSince1970: 1_700_060_000),
            repoSummaries: [],
            draftRepos: [],
            totalCommits: 0,
            activeRepoCount: 0
        )
        let data = try JSONEncoder.pilo.encode(old)
        let letter = try JSONDecoder.pilo.decode(DailyLetter.self, from: data)
        XCTAssertNil(letter.aiCompanions, "旧 JSON 无该字段 → fallback nil")
        XCTAssertEqual(letter.totalCommits, 0)
    }

    func testDailyLetterRoundTripWithCompanions() throws {
        let letter = DailyLetter(
            id: UUID(),
            date: Date(timeIntervalSince1970: 1_700_000_000),
            deliveredAt: Date(timeIntervalSince1970: 1_700_060_000),
            readAt: nil,
            repoSummaries: [],
            draftRepos: [],
            totalCommits: 0,
            activeRepoCount: 0,
            aiCompanions: [
                .init(tool: .claudeCode, activityCount: 3),
                .init(tool: .cursor, activityCount: 2),
            ]
        )
        let data = try JSONEncoder.pilo.encode(letter)
        let decoded = try JSONDecoder.pilo.decode(DailyLetter.self, from: data)
        XCTAssertEqual(decoded.aiCompanions?.count, 2)
        XCTAssertEqual(decoded.aiCompanions?.first?.tool, .claudeCode)
        XCTAssertEqual(decoded.aiCompanions?.first?.activityCount, 3)
    }

    // MARK: - AICompanionSummary self round-trip

    func testCompanionSummaryCodableRoundTrip() throws {
        let summary = AICompanionSummary(tool: .gemini, activityCount: 5)
        let data = try JSONEncoder.pilo.encode(summary)
        let decoded = try JSONDecoder.pilo.decode(AICompanionSummary.self, from: data)
        XCTAssertEqual(decoded.tool, .gemini)
        XCTAssertEqual(decoded.activityCount, 5)
    }

    // MARK: - Detector

    func testDetectorReturnsArrayWithoutCrashing() async {
        // 不依赖用户机器有什么 AI 工具 —— 只验证：
        //  1. 调用不抛错 / 不 crash
        //  2. 返回的结果都 activityCount > 0（detector 过滤了 0 的）
        //  3. 结果按 count 倒序
        let detector = AICompanionDetector()
        let results = await detector.detectActivity(repos: [], date: Date())
        for r in results {
            XCTAssertGreaterThan(r.activityCount, 0, "0 活动 tool 不应出现在结果里")
        }
        for i in 1..<results.count {
            XCTAssertGreaterThanOrEqual(
                results[i - 1].activityCount, results[i].activityCount,
                "结果按 activityCount 倒序"
            )
        }
    }

    func testDetectorIgnoresYesterdayInAiderRepo() async throws {
        // 用 temp dir 模拟一个 repo 有 .aider.chat.history.md mtime 是昨天
        // detector 应该 NOT 把它计为 today active
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PiloAiderTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let aiderFile = tempRoot.appendingPathComponent(".aider.chat.history.md")
        FileManager.default.createFile(atPath: aiderFile.path, contents: Data("x".utf8))
        // 强制 mtime 设为昨天
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        try FileManager.default.setAttributes(
            [.modificationDate: yesterday],
            ofItemAtPath: aiderFile.path
        )

        let repo = Repository(path: tempRoot.path)
        let detector = AICompanionDetector()
        let results = await detector.detectActivity(repos: [repo], date: Date())
        XCTAssertFalse(
            results.contains { $0.tool == .aider },
            "昨天的 .aider mtime 不应被算成今天活动"
        )
    }

    func testDetectorPicksUpTodayAiderRepo() async throws {
        // 跟上面对称：mtime 今天 → 应该被算
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PiloAiderTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let aiderFile = tempRoot.appendingPathComponent(".aider.chat.history.md")
        FileManager.default.createFile(atPath: aiderFile.path, contents: Data("x".utf8))
        // mtime = now（默认就是 now，但显式 set 保险）
        try FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: aiderFile.path
        )

        let repo = Repository(path: tempRoot.path)
        let detector = AICompanionDetector()
        let results = await detector.detectActivity(repos: [repo], date: Date())
        let aiderResult = results.first { $0.tool == .aider }
        XCTAssertNotNil(aiderResult, "今天 mtime 的 .aider repo 应该被算成 active")
        XCTAssertEqual(aiderResult?.activityCount, 1)
    }
}
