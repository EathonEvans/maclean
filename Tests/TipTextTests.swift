import XCTest
@testable import maclean

/// 中央提示文案随悬停时长格式化（用户 2026-11-11 决策：提示常驻屏幕中央、时长可配置）。
final class TipTextTests: XCTestCase {
    func testSecondsTextFormatsIntegersWithoutDecimals() {
        XCTAssertEqual(HoverTipFormatter.secondsText(2.0), "2")
        XCTAssertEqual(HoverTipFormatter.secondsText(5.0), "5")
        XCTAssertEqual(HoverTipFormatter.secondsText(1.0), "1")
    }

    func testSecondsTextKeepsOneDecimalForFractions() {
        XCTAssertEqual(HoverTipFormatter.secondsText(1.5), "1.5")
        XCTAssertEqual(HoverTipFormatter.secondsText(0.5), "0.5")
        XCTAssertEqual(HoverTipFormatter.secondsText(2.5), "2.5")
    }

    func testSecondsTextRoundsFloatingNoise() {
        // 滑块步进可能产生 1.4999999 之类的浮点噪声
        XCTAssertEqual(HoverTipFormatter.secondsText(1.4999999), "1.5")
        XCTAssertEqual(HoverTipFormatter.secondsText(1.9499999), "1.9")
    }

    func testTipTextContainsDurationAndInstruction() {
        let text = HoverTipFormatter.tipText(1.5)
        XCTAssertTrue(text.contains("1.5"))
        XCTAssertTrue(text.contains("悬停"))
        XCTAssertTrue(text.contains("秒即可退出"))
        XCTAssertEqual(text, "悬停 1.5 秒即可退出")
    }

    func testDefaultConstantMatchesDesign() {
        XCTAssertEqual(AppConstants.defaultHoverDuration, 1.5)
        XCTAssertEqual(HoverTipFormatter.tipText(AppConstants.defaultHoverDuration), "悬停 1.5 秒即可退出")
    }
}
