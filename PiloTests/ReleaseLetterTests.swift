import XCTest
@testable import Pilo

/// ReleaseLetter / Semver / 持久化测试
final class ReleaseLetterTests: XCTestCase {

    // MARK: - Semver

    func testSemverEqual() {
        XCTAssertEqual(Semver.compare("0.4.0", "0.4.0"), .orderedSame)
        XCTAssertEqual(Semver.compare("1.0", "1.0.0"), .orderedSame)  // 缺位补 0
    }

    func testSemverAscending() {
        XCTAssertEqual(Semver.compare("0.3.0", "0.4.0"), .orderedAscending)
        XCTAssertEqual(Semver.compare("0.4.0", "0.4.1"), .orderedAscending)
        XCTAssertEqual(Semver.compare("0.0.0", "0.1.0"), .orderedAscending)
    }

    func testSemverDescending() {
        XCTAssertEqual(Semver.compare("0.4.0", "0.3.0"), .orderedDescending)
        XCTAssertEqual(Semver.compare("1.0.0", "0.99.0"), .orderedDescending)
    }

    func testSemverNumericNotLexicographic() {
        // 关键 case："10" 比 "9" 大 —— 字符串排序会反过来
        XCTAssertEqual(Semver.compare("1.10.0", "1.9.0"), .orderedDescending,
                       "1.10 应大于 1.9（数字比较，非字符串）")
    }

    func testSemverNonNumericPartsTreatedAsZero() {
        // "0.4-beta" 的 "4-beta" 解析为 0 —— 不崩，保守失败
        let r = Semver.compare("0.4-beta", "0.4.0")
        XCTAssertNotEqual(r, .orderedDescending,
                          "非数字段不应该被误认为更大版本")
    }

    // MARK: - ReleaseLetter Codable

    func testReleaseLetterRoundTrip() throws {
        let original = ReleaseLetter(
            id: UUID(),
            version: "0.4.0",
            releaseDate: Date(timeIntervalSince1970: 1_715_000_000),
            deliveredAt: Date(timeIntervalSince1970: 1_715_500_000),
            readAt: nil,
            title: "测试通告",
            highlights: ["a", "b"],
            bodyParagraphs: ["段落 1", "段落 2"]
        )
        let data = try JSONEncoder.pilo.encode(original)
        let decoded = try JSONDecoder.pilo.decode(ReleaseLetter.self, from: data)
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.version, decoded.version)
        XCTAssertEqual(original.title, decoded.title)
        XCTAssertEqual(original.highlights, decoded.highlights)
        XCTAssertEqual(original.bodyParagraphs, decoded.bodyParagraphs)
    }

    func testReleaseLetterArchiveRoundTrip() throws {
        let archive = ReleaseLetterArchive(
            version: 1,
            letters: [
                ReleaseLetter(
                    id: UUID(),
                    version: "0.3.0",
                    releaseDate: Date(),
                    deliveredAt: Date(),
                    readAt: Date(),
                    title: "v0.3",
                    highlights: [],
                    bodyParagraphs: []
                ),
                ReleaseLetter(
                    id: UUID(),
                    version: "0.4.0",
                    releaseDate: Date(),
                    deliveredAt: Date(),
                    readAt: nil,
                    title: "v0.4",
                    highlights: ["x"],
                    bodyParagraphs: ["y"]
                ),
            ]
        )
        let data = try JSONEncoder.pilo.encode(archive)
        let decoded = try JSONDecoder.pilo.decode(ReleaseLetterArchive.self, from: data)
        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.letters.count, 2)
        XCTAssertNil(decoded.letters[1].readAt)
    }

    func testIsUnreadFlag() {
        let unread = ReleaseLetter(
            id: UUID(), version: "0.4.0",
            releaseDate: Date(), deliveredAt: Date(), readAt: nil,
            title: "t", highlights: [], bodyParagraphs: []
        )
        XCTAssertTrue(unread.isUnread)

        let read = ReleaseLetter(
            id: UUID(), version: "0.4.0",
            releaseDate: Date(), deliveredAt: Date(), readAt: Date(),
            title: "t", highlights: [], bodyParagraphs: []
        )
        XCTAssertFalse(read.isUnread)
    }

    // MARK: - InboxItem 排序

    func testInboxItemsSortByDateDesc() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let dayBefore = cal.date(byAdding: .day, value: -2, to: today)!

        let daily = DailyLetter(
            id: UUID(), date: yesterday, deliveredAt: yesterday,
            readAt: nil, repoSummaries: [], draftRepos: [],
            totalCommits: 0, activeRepoCount: 0
        )
        let releaseToday = ReleaseLetter(
            id: UUID(), version: "0.4.0",
            releaseDate: today, deliveredAt: today, readAt: nil,
            title: "v0.4", highlights: [], bodyParagraphs: []
        )
        let releaseOld = ReleaseLetter(
            id: UUID(), version: "0.3.0",
            releaseDate: dayBefore, deliveredAt: dayBefore, readAt: nil,
            title: "v0.3", highlights: [], bodyParagraphs: []
        )

        let items: [InboxItem] = [
            .daily(daily),
            .release(releaseToday),
            .release(releaseOld),
        ]
        let sorted = items.sorted { $0.sortDate > $1.sortDate }
        // 期望顺序：today > yesterday > dayBefore
        if case .release(let r) = sorted[0] { XCTAssertEqual(r.version, "0.4.0") } else { XCTFail() }
        if case .daily = sorted[1] {} else { XCTFail() }
        if case .release(let r) = sorted[2] { XCTAssertEqual(r.version, "0.3.0") } else { XCTFail() }
    }

    func testInboxItemUnreadFlag() {
        let unread = InboxItem.release(ReleaseLetter(
            id: UUID(), version: "0.4", releaseDate: Date(), deliveredAt: Date(),
            readAt: nil, title: "t", highlights: [], bodyParagraphs: []
        ))
        XCTAssertTrue(unread.isUnread)

        let read = InboxItem.release(ReleaseLetter(
            id: UUID(), version: "0.4", releaseDate: Date(), deliveredAt: Date(),
            readAt: Date(), title: "t", highlights: [], bodyParagraphs: []
        ))
        XCTAssertFalse(read.isUnread)
    }

    // MARK: - Bundled JSON

    func testBundledReleaseNotesLoadsAtLeastV0_4() {
        // 守 release-notes.json 跟 app binary 一起 ship + 解析正确
        let releases = ReleaseNotesLoader.bundledReleases()
        XCTAssertFalse(releases.isEmpty, "release-notes.json 必须 bundle 进 app")
        XCTAssertTrue(releases.contains { $0.version == "0.4.0" },
                      "v0.4.0 必须在 bundled releases 里")
    }

    func testCurrentAppVersionPresent() {
        // Info.plist 应该有 CFBundleShortVersionString
        XCTAssertNotNil(ReleaseNotesLoader.currentAppVersion())
    }
}
