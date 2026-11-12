import CoreGraphics
import XCTest
@testable import maclean

/// 悬停计时行为矩阵（开发文档 §5.3 H01–H12 中可自动化的纯逻辑部分）。
/// 热区 = 屏幕中央 HUD 区域（用户 2026-11-11 决策）。
/// 使用注入的合成时钟与合成采样点，不依赖真实鼠标。
@MainActor
final class HoverTimingTests: XCTestCase {
    // A 屏 (0,0,1920,1080) 中央热区；B 屏 (-1080,-420,1080,1920) 中央热区
    private let screenA = DisplayHotspot(displayID: 1, rect: CGRect(x: 780, y: 460, width: 360, height: 160))
    private let screenB = DisplayHotspot(displayID: 2, rect: CGRect(x: -720, y: 460, width: 360, height: 160))
    // 各屏热区中心点（悬停目标）
    private let pointA = CGPoint(x: 960, y: 540)
    private let pointB = CGPoint(x: -540, y: 540)
    // 各屏热区外的点
    private let outsideA = CGPoint(x: 200, y: 200)
    private let outsideB = CGPoint(x: -1040, y: -380)

    private func makeMonitor(clock: @escaping () -> CFTimeInterval) -> MousePositionMonitor {
        let monitor = MousePositionMonitor()
        monitor.now = clock
        monitor.hoverDuration = 1.5
        monitor.installHotspotsForTesting([screenA, screenB])
        return monitor
    }

    /// 可推进的合成时钟
    private final class FakeClock {
        var now: CFTimeInterval = 0
        func read() -> CFTimeInterval { now }
        func advance(_ seconds: CFTimeInterval) { now += seconds }
    }

    func testH02EnterHotspotFiresEnterAndStartsFromZero() {
        let clock = FakeClock()
        let monitor = makeMonitor(clock: clock.read)
        var enterCount = 0
        var progressValues: [Double] = []
        monitor.onEnter = { _ in enterCount += 1 }
        monitor.onProgress = { progressValues.append($0) }

        monitor.isRunningForTesting = true

        // 鼠标在热区外
        monitor.sample(at: outsideA)
        XCTAssertEqual(enterCount, 0)

        // 进入 A 屏中央热区：进入当帧进度为 0，随后按经过时间增长
        clock.advance(0.1)
        monitor.sample(at: pointA)
        XCTAssertEqual(enterCount, 1)
        XCTAssertEqual(progressValues.first ?? -1, 0, accuracy: 0.0001)

        clock.advance(0.1)
        monitor.sample(at: pointA)
        XCTAssertEqual(progressValues.last ?? -1, 0.1 / 1.5, accuracy: 0.0001)
    }

    func testH03H04H05StaysThroughCompletion() {
        let clock = FakeClock()
        let monitor = makeMonitor(clock: clock.read)
        var completed = 0
        var lastProgress = 0.0
        monitor.onProgress = { lastProgress = $0 }
        monitor.onCompleted = { completed += 1 }
        monitor.isRunningForTesting = true

        monitor.sample(at: pointA)   // 进入，t=0

        clock.advance(0.5)
        monitor.sample(at: pointA)
        XCTAssertEqual(lastProgress, 0.5 / 1.5, accuracy: 0.0001)
        XCTAssertEqual(completed, 0)

        clock.advance(0.5)   // 累计 1.0s
        monitor.sample(at: pointA)
        XCTAssertEqual(lastProgress, 1.0 / 1.5, accuracy: 0.0001)
        XCTAssertEqual(completed, 0)

        clock.advance(0.5)   // 累计 1.5s
        monitor.sample(at: pointA)
        XCTAssertEqual(lastProgress, 1.0, accuracy: 0.0001)
        XCTAssertEqual(completed, 1)
        // 完成后自动停止采样（§5.5 注 2）
        XCTAssertFalse(monitor.isRunning)
    }

    func testH06H08LeaveResetsImmediatelyAndDoesNotAccumulate() {
        let clock = FakeClock()
        let monitor = makeMonitor(clock: clock.read)
        var leaveCount = 0
        var lastProgress = -1.0
        monitor.onLeave = { leaveCount += 1 }
        monitor.onProgress = { lastProgress = $0 }
        monitor.isRunningForTesting = true

        monitor.sample(at: pointA)      // 进入
        clock.advance(1.0)              // 停留 1 秒
        monitor.sample(at: pointA)
        XCTAssertEqual(lastProgress, 1.0 / 1.5, accuracy: 0.0001)

        // 离开（哪怕一个检测周期）：立即归零，不累计
        monitor.sample(at: outsideA)
        XCTAssertEqual(leaveCount, 1)

        // 离开期间经过的时间不计入下次悬停
        clock.advance(10)
        monitor.sample(at: outsideA)
        XCTAssertEqual(leaveCount, 1)

        // 重新进入：进入当帧进度为 0，随后从 0 重新计时（H07）
        clock.advance(0.2)
        monitor.sample(at: pointA)
        XCTAssertEqual(leaveCount, 1)
        XCTAssertEqual(lastProgress, 0, accuracy: 0.0001)

        clock.advance(0.2)
        monitor.sample(at: pointA)
        XCTAssertEqual(lastProgress, 0.2 / 1.5, accuracy: 0.0001)
    }

    func testH09CrossScreenSwitchResetsTimer() {
        let clock = FakeClock()
        let monitor = makeMonitor(clock: clock.read)
        var enteredDisplays: [CGDirectDisplayID] = []
        var leaveCount = 0
        var lastProgress = -1.0
        monitor.onEnter = { enteredDisplays.append($0) }
        monitor.onLeave = { leaveCount += 1 }
        monitor.onProgress = { lastProgress = $0 }
        monitor.isRunningForTesting = true

        // A 屏热区停留 1 秒
        monitor.sample(at: pointA)
        clock.advance(1.0)
        monitor.sample(at: pointA)

        // 直接进入 B 屏热区：先离开 A 再进入 B，B 从 0 开始（§5.6、§1.7）
        monitor.sample(at: pointB)
        XCTAssertEqual(enteredDisplays, [1, 2])
        XCTAssertEqual(leaveCount, 1)
        XCTAssertEqual(lastProgress, 0, accuracy: 0.0001)

        // B 从 0 重新计满 1.5 秒才完成
        var completed = false
        monitor.onCompleted = { completed = true }
        clock.advance(1.0)
        monitor.sample(at: pointB)
        XCTAssertFalse(completed)
        clock.advance(0.5)
        monitor.sample(at: pointB)
        XCTAssertTrue(completed)
    }

    func testH10StaticHoverCompletesWithoutMovement() {
        let clock = FakeClock()
        let monitor = makeMonitor(clock: clock.read)
        var completed = 0
        monitor.onCompleted = { completed += 1 }
        monitor.isRunningForTesting = true

        monitor.sample(at: pointA)   // 进入
        // 鼠标静止：重复同一点采样
        for step in 1...5 {
            clock.advance(0.4)   // 累计到 2.0s
            monitor.sample(at: pointA)
            if completed > 0 { break }
            XCTAssertLessThan(Double(step) * 0.4, 1.5 + 0.3)
        }
        XCTAssertEqual(completed, 1, "静止悬停也必须完成计时")
    }

    func testH11MonotonicClockIgnoresSampleGaps() {
        // 主线程繁忙导致采样间隔拉长：按真实经过时间计算（§5.4）
        let clock = FakeClock()
        let monitor = makeMonitor(clock: clock.read)
        var completed = 0
        monitor.onCompleted = { completed += 1 }
        monitor.isRunningForTesting = true

        monitor.sample(at: pointA)
        clock.advance(3.0)   // 3 秒没有任何采样
        monitor.sample(at: pointA)
        XCTAssertEqual(completed, 1, "真实 elapsed 已超过 1.5 秒，应当完成")
    }

    func testSampleIgnoredWhenNotRunning() {
        let monitor = makeMonitor(clock: { 0 })
        var enterCount = 0
        monitor.onEnter = { _ in enterCount += 1 }
        // 未 start：sample 无效
        monitor.sample(at: pointA)
        XCTAssertEqual(enterCount, 0)
    }

    func testHysteresisEdgeJitterDoesNotReset() {
        // 滞后带（用户 2026-11-11 批准）：离开判定比进入判定外扩 6pt，
        // 边缘 4pt 内的抖动不清零；超出滞后带才真正离开
        let clock = FakeClock()
        let monitor = makeMonitor(clock: clock.read)
        var leaveCount = 0
        var lastProgress = -1.0
        monitor.onLeave = { leaveCount += 1 }
        monitor.onProgress = { lastProgress = $0 }
        monitor.isRunningForTesting = true

        monitor.sample(at: pointA)          // 进入（热区 x 780..1140）
        clock.advance(1.0)
        monitor.sample(at: pointA)
        XCTAssertEqual(lastProgress, 1.0 / 1.5, accuracy: 0.0001)

        // 右边缘外 4pt（滞后带 6pt 内）：不触发离开，计时继续
        monitor.sample(at: CGPoint(x: 1144, y: 540))
        XCTAssertEqual(leaveCount, 0)
        clock.advance(0.1)
        monitor.sample(at: CGPoint(x: 1144, y: 540))
        XCTAssertEqual(lastProgress, 1.1 / 1.5, accuracy: 0.0001)

        // 远超滞后带：立即离开归零
        monitor.sample(at: CGPoint(x: 1300, y: 540))
        XCTAssertEqual(leaveCount, 1)

        // 滞后带对进入判定无效：必须先真正进入真热区才开始计时
        clock.advance(0.5)
        monitor.sample(at: CGPoint(x: 1144, y: 540))
        XCTAssertEqual(leaveCount, 1, "滞后带只延缓离开，不放宽进入")
    }

    func testDefaultsMatchProductSpec() {
        XCTAssertEqual(AppConstants.defaultHoverDuration, 1.5)
        XCTAssertTrue(AppConstants.hoverDurationRange.contains(AppConstants.defaultHoverDuration))
    }
}
