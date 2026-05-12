import XCTest
@testable import Pilo

/// UpdateChecker 测试 —— 注入 fetcher closure，避免真实网络 / URLProtocol mock 的
/// 生命周期 / 并发坑。
final class UpdateCheckerTests: XCTestCase {

    private static let testURL = URL(string: "https://example.com/updates.json")!

    private func makeChecker(returnData: Data?) -> UpdateChecker {
        let fetcher: UpdateChecker.Fetcher = { _ in returnData }
        return UpdateChecker(manifestURL: Self.testURL, fetcher: fetcher)
    }

    // MARK: - 新版本可用

    func testReturnsLetterWhenNewerVersionAvailable() async {
        let manifest = """
        {
          "latest": {
            "version": "0.5.0",
            "releaseDate": "2026-06-01",
            "title": "v0.5 测试通告",
            "highlights": ["a", "b"],
            "downloadURL": "https://example.com/dl.dmg",
            "releaseNotesURL": "https://example.com/notes",
            "minimumSystemVersion": "14.0"
          }
        }
        """.data(using: .utf8)!

        let checker = makeChecker(returnData: manifest)
        let letter = await checker.check(currentAppVersion: "0.4.0")
        XCTAssertNotNil(letter)
        XCTAssertEqual(letter?.version, "0.5.0")
        XCTAssertEqual(letter?.title, "v0.5 测试通告")
        XCTAssertEqual(letter?.highlights, ["a", "b"])
        XCTAssertEqual(letter?.downloadURL.absoluteString, "https://example.com/dl.dmg")
    }

    // MARK: - 不应推送的场景

    func testReturnsNilWhenCurrentEqualsManifest() async {
        let manifest = """
        {"latest":{"version":"0.4.0","releaseDate":"2026-05-12","title":"x","highlights":[],"downloadURL":"https://x/d","releaseNotesURL":null,"minimumSystemVersion":null}}
        """.data(using: .utf8)!
        let checker = makeChecker(returnData: manifest)
        let letter = await checker.check(currentAppVersion: "0.4.0")
        XCTAssertNil(letter, "manifest 跟当前版本相同 → 不推送")
    }

    func testReturnsNilWhenCurrentNewerThanManifest() async {
        let manifest = """
        {"latest":{"version":"0.3.0","releaseDate":"2026-04-01","title":"x","highlights":[],"downloadURL":"https://x/d","releaseNotesURL":null,"minimumSystemVersion":null}}
        """.data(using: .utf8)!
        let checker = makeChecker(returnData: manifest)
        let letter = await checker.check(currentAppVersion: "0.4.0")
        XCTAssertNil(letter, "current > manifest → 不推送（不显示『回退』）")
    }

    // MARK: - 错误处理

    func testReturnsNilOnFetchFailure() async {
        let checker = makeChecker(returnData: nil)
        let letter = await checker.check(currentAppVersion: "0.4.0")
        XCTAssertNil(letter, "fetcher 返回 nil → 静默 nil")
    }

    func testReturnsNilOnMalformedJSON() async {
        let bad = "not json".data(using: .utf8)!
        let checker = makeChecker(returnData: bad)
        let letter = await checker.check(currentAppVersion: "0.4.0")
        XCTAssertNil(letter)
    }

    func testReturnsNilOnEmptyData() async {
        let checker = makeChecker(returnData: Data())
        let letter = await checker.check(currentAppVersion: "0.4.0")
        XCTAssertNil(letter)
    }

    // MARK: - 频控

    func testShouldCheckNowIsTrueOnFirstCall() async {
        let checker = makeChecker(returnData: nil)
        let should = await checker.shouldCheckNow()
        XCTAssertTrue(should, "首次必检查")
    }

    func testShouldCheckNowFalseRightAfterCheck() async {
        let manifest = """
        {"latest":{"version":"0.4.0","releaseDate":"2026-05-12","title":"x","highlights":[],"downloadURL":"https://x/d","releaseNotesURL":null,"minimumSystemVersion":null}}
        """.data(using: .utf8)!
        let checker = makeChecker(returnData: manifest)
        _ = await checker.check(currentAppVersion: "0.4.0")
        let should = await checker.shouldCheckNow()
        XCTAssertFalse(should, "刚检查完 24h 内不应再检")
    }

    // MARK: - 模型 round-trip

    func testUpdateAvailableLetterRoundTrip() throws {
        let original = UpdateAvailableLetter(
            id: UUID(),
            version: "0.5.0",
            releaseDate: Date(timeIntervalSince1970: 1_720_000_000),
            detectedAt: Date(timeIntervalSince1970: 1_720_100_000),
            readAt: nil,
            title: "新通告",
            highlights: ["a"],
            downloadURL: URL(string: "https://example.com/dmg")!,
            releaseNotesURL: URL(string: "https://example.com/notes")
        )
        let data = try JSONEncoder.pilo.encode(original)
        let decoded = try JSONDecoder.pilo.decode(UpdateAvailableLetter.self, from: data)
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.version, decoded.version)
        XCTAssertEqual(original.downloadURL, decoded.downloadURL)
    }

    func testUpdateAvailableArchiveRoundTrip() throws {
        let letter = UpdateAvailableLetter(
            id: UUID(),
            version: "0.5.0",
            releaseDate: Date(),
            detectedAt: Date(),
            readAt: nil,
            title: "t",
            highlights: [],
            downloadURL: URL(string: "https://x/d")!,
            releaseNotesURL: nil
        )
        let archive = UpdateAvailableArchive(version: 1, current: letter)
        let data = try JSONEncoder.pilo.encode(archive)
        let decoded = try JSONDecoder.pilo.decode(UpdateAvailableArchive.self, from: data)
        XCTAssertEqual(decoded.current?.version, "0.5.0")
    }

    func testEmptyArchiveRoundTrip() throws {
        let archive = UpdateAvailableArchive(version: 1, current: nil)
        let data = try JSONEncoder.pilo.encode(archive)
        let decoded = try JSONDecoder.pilo.decode(UpdateAvailableArchive.self, from: data)
        XCTAssertNil(decoded.current)
    }
}
