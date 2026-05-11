import XCTest
@testable import Pilo

final class CopyToneTests: XCTestCase {

    func testTonesReturnDifferentStrings() {
        let friendly = Copy.menubarAllSynced(.friendly)
        let minimal = Copy.menubarAllSynced(.minimal)
        XCTAssertNotEqual(friendly, minimal, "Friendly 和 minimal 必须有不同的文案")
        XCTAssertTrue(friendly.contains("✨") || friendly.contains("～"),
                      "Friendly 文案应包含温柔标志（✨ 或 ～）")
        XCTAssertFalse(minimal.contains("✨"),
                      "Minimal 文案不应包含装饰 emoji")
    }

    func testPendingHeaderFormat() {
        let friendly = Copy.menubarPendingHeader(.friendly, count: 3)
        let minimal = Copy.menubarPendingHeader(.minimal, count: 3)
        XCTAssertTrue(friendly.contains("3"))
        XCTAssertTrue(minimal.contains("3"))
        XCTAssertTrue(friendly.contains("咕咕"))
        XCTAssertFalse(minimal.contains("咕咕"))
    }

    func testMascotA11yLabelChangesByTone() {
        let f = Copy.MascotA11y.label(for: .sleeping, tone: .friendly)
        let m = Copy.MascotA11y.label(for: .sleeping, tone: .minimal)
        XCTAssertEqual(f, "Pilo 正在小睡")
        XCTAssertEqual(m, "应用状态：空闲")
    }

    func testAllMoodsHaveA11yLabels() {
        for mood in PiloMascot.Mood.allCases {
            for tone in Tone.allCases {
                let label = Copy.MascotA11y.label(for: mood, tone: tone)
                XCTAssertFalse(label.isEmpty,
                               "mood=\(mood) tone=\(tone) 必须有无障碍 label")
            }
        }
    }

    func testToneDecodingFromRawValue() {
        XCTAssertEqual(Tone(rawValue: "friendly"), .friendly)
        XCTAssertEqual(Tone(rawValue: "minimal"), .minimal)
        XCTAssertNil(Tone(rawValue: "unknown"))
    }
}
