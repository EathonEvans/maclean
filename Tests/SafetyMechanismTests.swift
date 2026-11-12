import AppKit
import CoreGraphics
import XCTest
@testable import maclean

/// 紧急退出组合键判定与 CG→AppKit 坐标转换。
final class SafetyMechanismTests: XCTestCase {
    func testCleaningDurationBackstopMatchesProductDecision() {
        // 快捷键逃生通道已移除（用户 2026-11-12 决策：键盘全屏蔽无例外）；
        // 剩余兜底为 10 分钟时长上限
        XCTAssertEqual(AppConstants.maxCleaningDuration, 600)
    }

    // MARK: - CG → AppKit 坐标转换（tap 鼠标事件热区路径，开发文档 §5.2）

    func testCGPointFlipOnPrimaryScreen() {
        // 主屏高 1117（16" MacBook 默认缩放）：CG 原点在左上，AppKit 原点在左下
        XCTAssertEqual(
            MousePositionMonitor.appKitPoint(fromCG: CGPoint(x: 0, y: 0), primaryHeight: 1117),
            CGPoint(x: 0, y: 1117),
            "CG 左上角 → AppKit 左上角（y 最大）"
        )
        XCTAssertEqual(
            MousePositionMonitor.appKitPoint(fromCG: CGPoint(x: 1719, y: 1117), primaryHeight: 1117),
            CGPoint(x: 1719, y: 0),
            "CG 左下角 → AppKit 左下角（y 为 0）"
        )
        XCTAssertEqual(
            MousePositionMonitor.appKitPoint(fromCG: CGPoint(x: 860, y: 558.5), primaryHeight: 1117),
            CGPoint(x: 860, y: 558.5)
        )
    }

    func testCGPointFlipPreservesX() {
        let point = MousePositionMonitor.appKitPoint(fromCG: CGPoint(x: 2500, y: 40), primaryHeight: 1117)
        XCTAssertEqual(point.x, 2500)
        XCTAssertEqual(point.y, 1077)
    }

    func testHotspotCenterConsistentAcrossCoordinateSystems() {
        // 屏幕中央（HUD 热区）：AppKit 坐标 (W/2, H/2) 应等价于 CG 坐标翻转后的结果
        let width: CGFloat = 1720
        let height: CGFloat = 1117
        let fromAppKit = CGPoint(x: width / 2, y: height / 2)
        let fromCG = MousePositionMonitor.appKitPoint(
            fromCG: CGPoint(x: width / 2, y: height / 2),
            primaryHeight: height
        )
        XCTAssertEqual(fromAppKit, fromCG)

        // 两种来源（轮询 NSEvent 与 tap mouseMoved）都应命中中央热区
        let hotspot = DisplayHotspot(
            displayID: 1,
            rect: DisplayHotspot.rect(for: CGRect(x: 0, y: 0, width: width, height: height))
        )
        XCTAssertTrue(hotspot.contains(fromAppKit))
        XCTAssertTrue(hotspot.contains(fromCG))

        // 边缘采样点（鼠标贴近 HUD 边缘）也一致
        let edgeAppKit = CGPoint(x: width / 2 - 170, y: height / 2 + 40)
        let edgeCG = MousePositionMonitor.appKitPoint(
            fromCG: CGPoint(x: width / 2 - 170, y: height / 2 - 40),
            primaryHeight: height
        )
        XCTAssertEqual(edgeAppKit, edgeCG)
        XCTAssertTrue(hotspot.contains(edgeAppKit))
    }
}
