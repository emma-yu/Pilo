import XCTest
@testable import Pilo

/// DailyLetter 向后兼容回归测试。
///
/// 守的红线:旧 letters.json 缺后加字段(linesAdded / linesRemoved / topFiles /
/// aiCompanions / workSpan / addressee)时,**必须**仍能解码、用默认值兜底 —— 否则
/// LetterStore.load() 会 catch 成 .empty,用户静默丢失全部历史信。
final class DailyLetterCodableTests: XCTestCase {

    /// 构造一封"字段全满"的信(含所有后加字段),供两个测试复用。
    private func makeFullLetter() -> DailyLetter {
        DailyLetter(
            id: UUID(),
            date: Date(timeIntervalSince1970: 1_700_000_000),
            deliveredAt: Date(timeIntervalSince1970: 1_700_003_600),
            readAt: nil,
            repoSummaries: [
                .init(repoName: "demo", repoPath: "/demo", commitCount: 3, pushed: true,
                      remote: "origin",
                      commits: [.init(hash: "abc123", subject: "feat: x")],
                      linesAdded: 12, linesRemoved: 4)
            ],
            draftRepos: [
                .init(repoName: "wip", repoPath: "/wip", uncommittedCount: 2,
                      topFiles: ["a.swift", "b.swift"])
            ],
            totalCommits: 3,
            activeRepoCount: 1,
            workSpan: .init(firstCommit: Date(timeIntervalSince1970: 1_700_000_000),
                            lastCommit: Date(timeIntervalSince1970: 1_700_003_600)),
            addressee: "Emma",
            aiCompanions: [.init(tool: .claudeCode, activityCount: 2)]
        )
    }

    /// 全字段 round-trip:确认自定义 init(from:) 没漏/错任何字段。
    func testDailyLetterRoundTrip() throws {
        let letter = makeFullLetter()
        let data = try JSONEncoder.pilo.encode(letter)
        let decoded = try JSONDecoder.pilo.decode(DailyLetter.self, from: data)

        XCTAssertEqual(decoded.repoSummaries.count, 1)
        XCTAssertEqual(decoded.repoSummaries.first?.linesAdded, 12)
        XCTAssertEqual(decoded.repoSummaries.first?.linesRemoved, 4)
        XCTAssertEqual(decoded.repoSummaries.first?.commits.first?.hash, "abc123")
        XCTAssertEqual(decoded.draftRepos.first?.topFiles, ["a.swift", "b.swift"])
        XCTAssertEqual(decoded.aiCompanions?.count, 1)
        XCTAssertEqual(decoded.totalCommits, 3)
        XCTAssertNotNil(decoded.workSpan)
        XCTAssertEqual(decoded.addressee, "Emma")
    }

    /// 旧档兼容:用真实 encoder 编码后剥掉所有后加 key,模拟旧 letters.json,
    /// 必须仍能解码并落到默认值(不 throw)。没有 fix 前这个 case 会 throw keyNotFound。
    func testDailyLetterDecodesOldArchiveMissingNewFields() throws {
        let data = try JSONEncoder.pilo.encode(makeFullLetter())
        var obj = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        // 顶层后加字段
        obj.removeValue(forKey: "aiCompanions")
        obj.removeValue(forKey: "workSpan")
        obj.removeValue(forKey: "addressee")
        // repoSummaries[].linesAdded / linesRemoved
        if var repos = obj["repoSummaries"] as? [[String: Any]] {
            for i in repos.indices {
                repos[i].removeValue(forKey: "linesAdded")
                repos[i].removeValue(forKey: "linesRemoved")
            }
            obj["repoSummaries"] = repos
        }
        // draftRepos[].topFiles
        if var drafts = obj["draftRepos"] as? [[String: Any]] {
            for i in drafts.indices {
                drafts[i].removeValue(forKey: "topFiles")
            }
            obj["draftRepos"] = drafts
        }

        let oldData = try JSONSerialization.data(withJSONObject: obj)
        // 关键:不能 throw
        let decoded = try JSONDecoder.pilo.decode(DailyLetter.self, from: oldData)

        XCTAssertEqual(decoded.repoSummaries.first?.linesAdded, 0, "缺失 → 默认 0")
        XCTAssertEqual(decoded.repoSummaries.first?.linesRemoved, 0, "缺失 → 默认 0")
        XCTAssertEqual(decoded.draftRepos.first?.topFiles, [], "缺失 → 默认 []")
        XCTAssertNil(decoded.aiCompanions, "缺失 → nil")
        XCTAssertNil(decoded.workSpan, "缺失 → nil")
        XCTAssertNil(decoded.addressee, "缺失 → nil")
        // 已有字段不受影响
        XCTAssertEqual(decoded.totalCommits, 3)
        XCTAssertEqual(decoded.repoSummaries.first?.commits.first?.subject, "feat: x")
    }
}
