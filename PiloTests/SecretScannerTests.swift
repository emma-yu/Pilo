import XCTest
@testable import Pilo

final class SecretScannerTests: XCTestCase {

    var scanner: SecretScanner!
    let repoId = UUID()

    override func setUp() async throws {
        try await super.setUp()
        scanner = SecretScanner()
    }

    // MARK: - 加载规则

    func testRulesLoadFromBundle() async {
        let rules = await scanner.rules
        XCTAssertEqual(rules.count, 25, "应正好 25 条规则")
        // 抽几个关键规则确认存在
        let ids = Set(rules.map(\.id))
        XCTAssertTrue(ids.contains("openai-api-key"))
        XCTAssertTrue(ids.contains("anthropic-api-key"))
        XCTAssertTrue(ids.contains("github-pat-classic"))
        XCTAssertTrue(ids.contains("aws-access-key-id"))
        XCTAssertTrue(ids.contains("private-key"))
    }

    // MARK: - 命中规则

    func testOpenAIKeyDetected() async {
        let line = DiffLine(filePath: "config.js", newLineNumber: 12,
                            content: "const key = 'sk-proj-abcd1234efgh5678ijkl9012mnop3456qrst7890';")
        let findings = await scanner.scan(diffLines: [line], repoId: repoId, falsePositiveMarks: [])
        XCTAssertEqual(findings.count, 1)
        XCTAssertEqual(findings.first?.ruleId, "openai-api-key")
        XCTAssertEqual(findings.first?.severity, .critical)
        XCTAssertEqual(findings.first?.filePath, "config.js")
        XCTAssertEqual(findings.first?.lineNumber, 12)
    }

    func testGitHubPATDetected() async {
        let line = DiffLine(filePath: ".env", newLineNumber: 3,
                            content: "GITHUB_TOKEN=ghp_aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789")
        let findings = await scanner.scan(diffLines: [line], repoId: repoId, falsePositiveMarks: [])
        XCTAssertTrue(findings.contains { $0.ruleId == "github-pat-classic" })
    }

    func testPrivateKeyDetected() async {
        let line = DiffLine(filePath: "id_rsa", newLineNumber: 1,
                            content: "-----BEGIN OPENSSH PRIVATE KEY-----")
        let findings = await scanner.scan(diffLines: [line], repoId: repoId, falsePositiveMarks: [])
        XCTAssertEqual(findings.count, 1)
        XCTAssertEqual(findings.first?.ruleId, "private-key")
    }

    func testMongoDBConnectionDetected() async {
        let line = DiffLine(filePath: "src/db.ts", newLineNumber: 5,
                            content: "MONGODB_URI=mongodb+srv://admin:supersecret@cluster0.mongodb.net/db")
        let findings = await scanner.scan(diffLines: [line], repoId: repoId, falsePositiveMarks: [])
        XCTAssertTrue(findings.contains { $0.ruleId == "mongodb-conn-string" })
    }

    func testAnthropicKeyDetected() async {
        let line = DiffLine(filePath: "config.py", newLineNumber: 2,
                            content: "ANTHROPIC_API_KEY=sk-ant-api03-" + String(repeating: "abcdefABCD12345_-", count: 6))
        let findings = await scanner.scan(diffLines: [line], repoId: repoId, falsePositiveMarks: [])
        XCTAssertTrue(findings.contains { $0.ruleId == "anthropic-api-key" })
    }

    // MARK: - 不命中

    func testCleanCodeProducesNoFindings() async {
        let line = DiffLine(filePath: "foo.ts", newLineNumber: 1,
                            content: "export const greeting = 'hello world';")
        let findings = await scanner.scan(diffLines: [line], repoId: repoId, falsePositiveMarks: [])
        XCTAssertTrue(findings.isEmpty)
    }

    func testEnvExampleFileIsSkipped() async {
        let line = DiffLine(filePath: ".env.example", newLineNumber: 1,
                            content: "OPENAI_API_KEY=sk-proj-realLookingButFakeAaaaaaaaaaaaaaaaa")
        let findings = await scanner.scan(diffLines: [line], repoId: repoId, falsePositiveMarks: [])
        XCTAssertTrue(findings.isEmpty, ".env.example 必须跳过")
    }

    func testFixturesDirSkipped() async {
        let line = DiffLine(filePath: "test/__fixtures__/keys.txt", newLineNumber: 1,
                            content: "ghp_aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789")
        let findings = await scanner.scan(diffLines: [line], repoId: repoId, falsePositiveMarks: [])
        XCTAssertTrue(findings.isEmpty, "fixtures 目录必须跳过")
    }

    // MARK: - 熵校验

    func testLowEntropyOpenAIKeyFiltered() async {
        // sk-proj- 后接 "aaaaaa..."，熵很低
        let line = DiffLine(filePath: "test.ts", newLineNumber: 1,
                            content: "key = 'sk-proj-aaaaaaaaaaaaaaaaaaaaaaaa'")
        let findings = await scanner.scan(diffLines: [line], repoId: repoId, falsePositiveMarks: [])
        XCTAssertTrue(findings.filter { $0.ruleId == "openai-api-key" }.isEmpty,
                      "熵过低应过滤掉")
    }

    func testShannonEntropyCalc() {
        let high = SecretScanner.shannonEntropy("aBcDeF12gHiJkLmN")     // 多样字符
        let low  = SecretScanner.shannonEntropy("aaaaaaaaaaaaaaaa")     // 重复
        XCTAssertGreaterThan(high, low)
        XCTAssertGreaterThan(high, 3.0)
        XCTAssertLessThan(low, 1.0)
    }

    // MARK: - 误报标记过滤

    func testFalsePositiveMarkThisFileOnly() async {
        let line = DiffLine(filePath: "config.js", newLineNumber: 12,
                            content: "const key = 'sk-proj-abcd1234efgh5678ijkl9012mnop3456qrst7890';")
        let initial = await scanner.scan(diffLines: [line], repoId: repoId, falsePositiveMarks: [])
        XCTAssertEqual(initial.count, 1)

        let f = initial.first!
        let mark = FalsePositiveMark(
            rule: await scanner.rule(id: f.ruleId)!,
            scope: .thisFileOnly,
            finding: f
        )

        let filtered = await scanner.scan(diffLines: [line], repoId: repoId, falsePositiveMarks: [mark])
        XCTAssertTrue(filtered.isEmpty, "本文件标记后应过滤")
    }

    func testFalsePositiveMarkThisRule() async {
        let line1 = DiffLine(filePath: "a.js", newLineNumber: 1,
                             content: "k1 = 'sk-proj-abcd1234efgh5678ijkl9012mnop3456qrst7890'")
        let line2 = DiffLine(filePath: "b.js", newLineNumber: 1,
                             content: "k2 = 'sk-proj-AAA111BBB222CCC333DDD444EEE555FFF666GGG'")
        let initial = await scanner.scan(diffLines: [line1, line2], repoId: repoId, falsePositiveMarks: [])
        XCTAssertEqual(initial.count, 2)

        // 拿任一 finding 标记 thisRule
        let f = initial.first!
        let mark = FalsePositiveMark(
            rule: await scanner.rule(id: f.ruleId)!,
            scope: .thisRule,
            finding: f
        )

        let filtered = await scanner.scan(diffLines: [line1, line2], repoId: repoId, falsePositiveMarks: [mark])
        XCTAssertTrue(filtered.isEmpty, "整条规则标记后两处都应被过滤")
    }

    // MARK: - ScanFinding 掩码

    func testMaskingHidesMostOfToken() {
        let masked = ScanFinding.mask("sk-proj-abcdef1234567890")
        XCTAssertFalse(masked.contains("abcdef"))
        XCTAssertTrue(masked.contains("…"))
        XCTAssertTrue(masked.hasPrefix("sk-p"))
    }

    func testMaskingShortTokenAllStars() {
        let masked = ScanFinding.mask("abc")
        XCTAssertEqual(masked, "***")
    }
}
