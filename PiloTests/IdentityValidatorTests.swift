import XCTest
@testable import Pilo

/// S3 Identity Sentinel：IdentityValidator 启发式 + Mismatch 判定测试。
final class IdentityValidatorTests: XCTestCase {

    private func commit(_ email: String?) -> CommitSummary {
        CommitSummary(
            hash: UUID().uuidString.prefix(7).lowercased(),
            subject: "test",
            date: Date(),
            author: "Tester",
            authorEmail: email
        )
    }

    private let pool = IdentityPool(
        work: "work@company.com",
        personal: "12345+emma@users.noreply.github.com",
        experiment: nil   // 留空 → 沿用 personal
    )

    // MARK: - isSameIdentity

    func testSameIdentityExactMatch() {
        XCTAssertTrue(IdentityValidator.isSameIdentity("a@b.com", "a@b.com"))
    }

    func testSameIdentityCaseInsensitive() {
        XCTAssertTrue(IdentityValidator.isSameIdentity("A@B.com", "a@b.COM"))
    }

    func testDifferentEmailsAreNotSame() {
        XCTAssertFalse(IdentityValidator.isSameIdentity("a@b.com", "x@y.com"))
    }

    func testEmptyStringIsNotSame() {
        XCTAssertFalse(IdentityValidator.isSameIdentity("", "a@b.com"))
        XCTAssertFalse(IdentityValidator.isSameIdentity("a@b.com", ""))
    }

    func testGithubNoreplyBothUsername() {
        // 两个都是 noreply 同 username（id 不同）→ 同
        let a = "111+emma@users.noreply.github.com"
        let b = "999+emma@users.noreply.github.com"
        XCTAssertTrue(IdentityValidator.isSameIdentity(a, b))
    }

    func testGithubNoreplyVsPlain() {
        // noreply username = plain local-part → 视为同
        XCTAssertTrue(IdentityValidator.isSameIdentity(
            "12345+emma@users.noreply.github.com",
            "emma@personal.com"
        ))
    }

    // MARK: - validate

    func testValidateUnsetCategoryReturnsNil() {
        let result = IdentityValidator.validate(
            category: .unset,
            identityPool: pool,
            commits: [commit("wrong@whatever.com")],
            currentLocalEmail: nil
        )
        XCTAssertNil(result, "unset 类别应跳过检查")
    }

    func testValidateEmptyPoolReturnsNil() {
        let emptyPool = IdentityPool(work: nil, personal: nil, experiment: nil)
        let result = IdentityValidator.validate(
            category: .work,
            identityPool: emptyPool,
            commits: [commit("any@email.com")],
            currentLocalEmail: nil
        )
        XCTAssertNil(result, "空 pool 应跳过检查")
    }

    func testValidateAllMatchReturnsNil() {
        let result = IdentityValidator.validate(
            category: .work,
            identityPool: pool,
            commits: [
                commit("work@company.com"),
                commit("WORK@company.com"),    // case insensitive
            ],
            currentLocalEmail: "work@company.com"
        )
        XCTAssertNil(result)
    }

    func testValidateMismatchDetected() {
        let result = IdentityValidator.validate(
            category: .work,
            identityPool: pool,
            commits: [
                commit("personal@example.com"),
                commit("personal@example.com"),
                commit("work@company.com"),    // 这个 ok
            ],
            currentLocalEmail: "personal@example.com"
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.expectedEmail, "work@company.com")
        XCTAssertEqual(result?.actualEmail, "personal@example.com")
        XCTAssertEqual(result?.mismatchCount, 2)
    }

    func testExperimentFallsBackToPersonal() {
        // experiment 留空 → 用 personal 的 email
        let result = IdentityValidator.validate(
            category: .experiment,
            identityPool: pool,
            commits: [commit("12345+emma@users.noreply.github.com")],
            currentLocalEmail: nil
        )
        XCTAssertNil(result, "experiment 留空应用 personal 的 email 比较，匹配应通过")
    }

    func testNilAuthorEmailMatchesPlaceholder() {
        // 老 commits 没 authorEmail 字段 → 视为 ""，跟期望不同 = mismatch
        let result = IdentityValidator.validate(
            category: .work,
            identityPool: pool,
            commits: [commit(nil)],
            currentLocalEmail: nil
        )
        XCTAssertNotNil(result, "无 authorEmail 应视为不匹配")
    }
}

// MARK: - IdentityPool tests

final class IdentityPoolTests: XCTestCase {

    func testIsEmpty() {
        XCTAssertTrue(IdentityPool(work: nil, personal: nil, experiment: nil).isEmpty)
        XCTAssertTrue(IdentityPool(work: "", personal: "  ", experiment: nil).isEmpty)
        XCTAssertFalse(IdentityPool(work: "x@y.com", personal: nil, experiment: nil).isEmpty)
    }

    func testExpectedEmailExperimentFallback() {
        let pool = IdentityPool(work: "w@", personal: "p@", experiment: nil)
        XCTAssertEqual(pool.expectedEmail(for: .experiment), "p@")
    }

    func testExpectedEmailExperimentOverridesPersonal() {
        let pool = IdentityPool(work: "w@", personal: "p@", experiment: "e@")
        XCTAssertEqual(pool.expectedEmail(for: .experiment), "e@")
    }

    func testExpectedEmailUnsetReturnsNil() {
        let pool = IdentityPool(work: "w@", personal: "p@", experiment: "e@")
        XCTAssertNil(pool.expectedEmail(for: .unset))
    }
}
