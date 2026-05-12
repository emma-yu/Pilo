import XCTest
@testable import Pilo

/// DocReadingMemory: per-doc scroll memory 持久化测试。
/// 用 UserDefaults，每个测试用唯一 path 保证互不干扰；tearDown 清理。
final class DocReadingMemoryTests: XCTestCase {

    private var testRepoPath: String!
    private var keysWritten: [String] = []

    override func setUp() {
        super.setUp()
        // 每个 case 用 UUID 路径避免互相覆盖；同时是清理目标
        testRepoPath = "/tmp/pilo-test-\(UUID().uuidString)"
        keysWritten = []
    }

    override func tearDown() {
        // 清掉所有本次测试写入的 keys
        for key in keysWritten {
            UserDefaults.standard.removeObject(forKey: key)
        }
        super.tearDown()
    }

    private func recordKey(docRelativePath: String) {
        let key = DocReadingMemory.storageKey(
            repoPath: testRepoPath,
            docRelativePath: docRelativePath
        )
        keysWritten.append(key)
    }

    // MARK: - Save + restore

    func testSaveAndRestoreRoundTrip() {
        recordKey(docRelativePath: "README.md")
        DocReadingMemory.save(
            blockIndex: 42,
            repoPath: testRepoPath,
            docRelativePath: "README.md"
        )
        let restored = DocReadingMemory.savedBlockIndex(
            repoPath: testRepoPath,
            docRelativePath: "README.md"
        )
        XCTAssertEqual(restored, 42)
    }

    func testSaveZeroIsPersisted() {
        // 用户滚回顶部 (blockIndex 0) 也要保存 —— 跟"没存过 (nil)"区分
        recordKey(docRelativePath: "TOP.md")
        DocReadingMemory.save(
            blockIndex: 0,
            repoPath: testRepoPath,
            docRelativePath: "TOP.md"
        )
        let restored = DocReadingMemory.savedBlockIndex(
            repoPath: testRepoPath,
            docRelativePath: "TOP.md"
        )
        XCTAssertEqual(restored, 0, "0 应该被持久化，不等同于 nil")
    }

    func testMissingDocReturnsNil() {
        // 从未保存过的文档应返回 nil
        let restored = DocReadingMemory.savedBlockIndex(
            repoPath: testRepoPath,
            docRelativePath: "never-seen.md"
        )
        XCTAssertNil(restored)
    }

    // MARK: - 唯一性

    func testDifferentDocsHaveDifferentKeys() {
        // 同 repo 不同 doc → 不同 key
        let k1 = DocReadingMemory.storageKey(repoPath: testRepoPath, docRelativePath: "a.md")
        let k2 = DocReadingMemory.storageKey(repoPath: testRepoPath, docRelativePath: "b.md")
        XCTAssertNotEqual(k1, k2)
    }

    func testDifferentReposHaveDifferentKeys() {
        // 同名 doc 但不同 repo → 不同 key（关键：避免跨 repo 串号）
        let k1 = DocReadingMemory.storageKey(repoPath: "/repo/a", docRelativePath: "README.md")
        let k2 = DocReadingMemory.storageKey(repoPath: "/repo/b", docRelativePath: "README.md")
        XCTAssertNotEqual(k1, k2)
    }

    func testKeyIsStableAcrossCalls() {
        // 同样 input 应该总是同样 key（持久化的基础）
        let k1 = DocReadingMemory.storageKey(repoPath: testRepoPath, docRelativePath: "X.md")
        let k2 = DocReadingMemory.storageKey(repoPath: testRepoPath, docRelativePath: "X.md")
        XCTAssertEqual(k1, k2)
    }

    func testKeyDoesNotMergeWithBoundary() {
        // 防御：repoPath="/a" + doc="b/c.md" vs repoPath="/a/b" + doc="c.md"
        // —— 不带分隔符的话两者拼接相同，会撞 key
        let k1 = DocReadingMemory.storageKey(repoPath: "/a", docRelativePath: "b/c.md")
        let k2 = DocReadingMemory.storageKey(repoPath: "/a/b", docRelativePath: "c.md")
        XCTAssertNotEqual(k1, k2, "拼接边界不应导致 key 碰撞")
    }

    // MARK: - Clear

    func testClearRemovesValue() {
        recordKey(docRelativePath: "TO-CLEAR.md")
        DocReadingMemory.save(
            blockIndex: 99,
            repoPath: testRepoPath,
            docRelativePath: "TO-CLEAR.md"
        )
        XCTAssertNotNil(DocReadingMemory.savedBlockIndex(
            repoPath: testRepoPath,
            docRelativePath: "TO-CLEAR.md"
        ))

        DocReadingMemory.clear(
            repoPath: testRepoPath,
            docRelativePath: "TO-CLEAR.md"
        )

        XCTAssertNil(DocReadingMemory.savedBlockIndex(
            repoPath: testRepoPath,
            docRelativePath: "TO-CLEAR.md"
        ))
    }

    // MARK: - Overwrite

    func testSaveOverwritesPrevious() {
        recordKey(docRelativePath: "OVER.md")
        DocReadingMemory.save(
            blockIndex: 10,
            repoPath: testRepoPath,
            docRelativePath: "OVER.md"
        )
        DocReadingMemory.save(
            blockIndex: 50,
            repoPath: testRepoPath,
            docRelativePath: "OVER.md"
        )
        let restored = DocReadingMemory.savedBlockIndex(
            repoPath: testRepoPath,
            docRelativePath: "OVER.md"
        )
        XCTAssertEqual(restored, 50)
    }
}
