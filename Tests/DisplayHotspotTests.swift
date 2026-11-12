import CoreGraphics
import XCTest
@testable import maclean

/// 热区几何：热区 = 屏幕正中央 HUD 区域（用户 2026-11-11 决策，覆盖文档 §5.1"右上角"）。
/// 负坐标屏幕与边界判断规则不变（文档 §5.2）。
final class DisplayHotspotTests: XCTestCase {
    func testHotspotRectOnPositiveCoordinateScreen() {
        // 主屏 (0,0,1920,1080)：热区 = 正中央 360×160
        let rect = DisplayHotspot.rect(for: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        XCTAssertEqual(rect, CGRect(x: 780, y: 460, width: 360, height: 160))
    }

    func testHotspotRectOnNegativeCoordinateScreen() {
        // 外接屏在主屏左侧：x 为负（开发文档 §5.2 明确要求处理负坐标）
        let rect = DisplayHotspot.rect(for: CGRect(x: -1080, y: -420, width: 1080, height: 1920))
        XCTAssertEqual(rect, CGRect(x: -720, y: 460, width: 360, height: 160))
    }

    func testHotspotRectOnScaledScreen() {
        // 缩放比例只影响像素密度，frame 以点为单位，计算不受影响
        let rect = DisplayHotspot.rect(for: CGRect(x: 60, y: 0, width: 1512, height: 982))
        XCTAssertEqual(rect, CGRect(x: 636, y: 411, width: 360, height: 160))
    }

    func testContainsInsideHotspot() {
        let hotspot = DisplayHotspot(
            displayID: 1,
            rect: DisplayHotspot.rect(for: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        )
        XCTAssertTrue(hotspot.contains(CGPoint(x: 960, y: 540)))    // 屏幕中心
        XCTAssertTrue(hotspot.contains(CGPoint(x: 781, y: 491)))    // 左下角内
        XCTAssertTrue(hotspot.contains(CGPoint(x: 1139, y: 589)))   // 右上角内
    }

    func testDoesNotContainOutsideHotspot() {
        let hotspot = DisplayHotspot(
            displayID: 1,
            rect: DisplayHotspot.rect(for: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        )
        XCTAssertFalse(hotspot.contains(CGPoint(x: 779, y: 540)))    // 左边界外
        XCTAssertFalse(hotspot.contains(CGPoint(x: 1141, y: 540)))   // 右边界外
        XCTAssertFalse(hotspot.contains(CGPoint(x: 960, y: 459)))    // 下边界外
        XCTAssertFalse(hotspot.contains(CGPoint(x: 960, y: 621)))    // 上边界外
        XCTAssertFalse(hotspot.contains(CGPoint(x: 100, y: 100)))    // 屏幕左下角
        XCTAssertFalse(hotspot.contains(CGPoint(x: 1900, y: 1070)))  // 屏幕右上角
    }

    func testNegativeScreenContainsCenter() {
        let hotspot = DisplayHotspot(
            displayID: 2,
            rect: DisplayHotspot.rect(for: CGRect(x: -1080, y: -420, width: 1080, height: 1920))
        )
        // 该屏中心：midX=-540, midY=540
        XCTAssertTrue(hotspot.contains(CGPoint(x: -540, y: 540)))
        XCTAssertTrue(hotspot.contains(CGPoint(x: -600, y: 520)))
        XCTAssertFalse(hotspot.contains(CGPoint(x: -1, y: 1499)))   // 屏幕右上角
    }

    func testHotspotMatchesHUDFrameFormula() {
        // 热区与 HUD 面板摆放必须完全一致："看见的即悬停的"
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let hotspotRect = DisplayHotspot.rect(for: screenFrame)
        let hudRect = CleaningHUDManager.hudFrame(size: AppConstants.hudSize, in: screenFrame)
        XCTAssertEqual(hotspotRect, hudRect)
    }
}
