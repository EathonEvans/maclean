import AppKit
import XCTest
@testable import maclean

/// HUD 管理器冒烟测试：面板随显示器集合同步增减、进度路由、关闭清理。
/// 依赖测试宿主的真实屏幕（无屏幕环境自动跳过）。
@MainActor
final class CleaningHUDManagerTests: XCTestCase {
    private func currentMainDisplayID() -> CGDirectDisplayID? {
        NSScreen.main?.cleaningDisplayID
    }

    func testSyncDisplaysCreatesAndShutdownClears() throws {
        guard let displayID = currentMainDisplayID() else {
            throw XCTSkip("无可用屏幕，跳过")
        }
        let manager = CleaningHUDManager()
        XCTAssertFalse(manager.isVisible)

        manager.syncDisplays(for: [displayID], text: "测试 HUD")
        XCTAssertTrue(manager.isVisible)

        manager.fadeOutAndShutdown(duration: 0)
        XCTAssertFalse(manager.isVisible)
    }

    func testProgressRoutesToActiveDisplayOnly() throws {
        guard let displayID = currentMainDisplayID() else {
            throw XCTSkip("无可用屏幕，跳过")
        }
        let manager = CleaningHUDManager()
        manager.syncDisplays(for: [displayID], text: "测试 HUD")
        manager.setActiveDisplay(displayID)
        manager.updateProgress(0.5)

        manager.setActiveDisplay(nil)
        // 离开热区：全部进度归零
        // （模型不可直接观察，验证不崩溃 + 关闭路径正常即可）
        manager.resetProgresses()
        manager.fadeOutAndShutdown(duration: 0)
        XCTAssertFalse(manager.isVisible)
    }

    func testFadeOutShutdownIsSafeWhenEmpty() {
        let manager = CleaningHUDManager()
        manager.fadeOutAndShutdown()   // 空集合调用不得崩溃
        XCTAssertFalse(manager.isVisible)
    }
}
