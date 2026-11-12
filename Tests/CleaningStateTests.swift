import CoreGraphics
import XCTest
@testable import maclean

/// 清洁模式状态机转换规则（开发文档 §3，hovering 携带 displayID/startedAt）。
final class CleaningStateTests: XCTestCase {
    func testInitialStateIsIdle() {
        XCTAssertEqual(CleaningStateMachine().state, .idle)
    }

    func testHappyPathPrepareCleanHoverExit() {
        var machine = CleaningStateMachine()
        XCTAssertTrue(machine.request(.preparing))
        XCTAssertTrue(machine.request(.cleaning))
        XCTAssertTrue(machine.request(.hovering(displayID: 1, startedAt: 0)))
        XCTAssertTrue(machine.request(.exiting))
        XCTAssertTrue(machine.request(.idle))
        XCTAssertEqual(machine.state, .idle)
    }

    func testPrepareFailureRollsBackThroughFailed() {
        var machine = CleaningStateMachine()
        XCTAssertTrue(machine.request(.preparing))
        XCTAssertTrue(machine.request(.failed))
        XCTAssertTrue(machine.request(.idle))
        XCTAssertEqual(machine.state, .idle)
    }

    func testHoverLeaveRestoresCleaning() {
        var machine = CleaningStateMachine()
        XCTAssertTrue(machine.request(.preparing))
        XCTAssertTrue(machine.request(.cleaning))
        XCTAssertTrue(machine.request(.hovering(displayID: 1, startedAt: 0)))
        // 离开热区：hovering → cleaning
        XCTAssertTrue(machine.request(.cleaning))
        XCTAssertEqual(machine.state, .cleaning)
    }

    func testCrossScreenHoverSwitchIsAllowed() {
        // 从 A 屏热区直接进入 B 屏热区（开发文档 §1.7：重新计时）
        var machine = CleaningStateMachine()
        XCTAssertTrue(machine.request(.preparing))
        XCTAssertTrue(machine.request(.cleaning))
        XCTAssertTrue(machine.request(.hovering(displayID: 1, startedAt: 0)))
        XCTAssertTrue(machine.request(.hovering(displayID: 2, startedAt: 10)))
        if case .hovering(let displayID, let startedAt) = machine.state {
            XCTAssertEqual(displayID, 2)
            XCTAssertEqual(startedAt, 10)
        } else {
            XCTFail("应为 hovering(2)")
        }
    }

    func testAbnormalExitFromCleaningAndHoveringAllowed() {
        // 关键资源异常：cleaning/hovering → exiting（§1.10 安全恢复）
        var machine = CleaningStateMachine()
        XCTAssertTrue(machine.request(.preparing))
        XCTAssertTrue(machine.request(.cleaning))
        XCTAssertTrue(machine.request(.exiting))
        XCTAssertTrue(machine.request(.idle))

        var machine2 = CleaningStateMachine()
        XCTAssertTrue(machine2.request(.preparing))
        XCTAssertTrue(machine2.request(.cleaning))
        XCTAssertTrue(machine2.request(.hovering(displayID: 1, startedAt: 0)))
        XCTAssertTrue(machine2.request(.exiting))
        XCTAssertTrue(machine2.request(.idle))
    }

    func testIllegalTransitionsRejected() {
        var machine = CleaningStateMachine()

        // idle 只能进 preparing
        XCTAssertFalse(machine.request(.cleaning))
        XCTAssertFalse(machine.request(.exiting))
        XCTAssertFalse(machine.request(.failed))
        XCTAssertFalse(machine.request(.hovering(displayID: 1, startedAt: 0)))
        XCTAssertEqual(machine.state, .idle, "非法转换不得改变状态")

        // preparing 不能直接进 cleaning 之外的状态
        XCTAssertTrue(machine.request(.preparing))
        XCTAssertFalse(machine.request(.hovering(displayID: 1, startedAt: 0)))
        XCTAssertFalse(machine.request(.exiting))
        XCTAssertFalse(machine.request(.idle))

        // cleaning 不能直接回 idle / preparing / failed
        XCTAssertTrue(machine.request(.cleaning))
        XCTAssertFalse(machine.request(.idle))
        XCTAssertFalse(machine.request(.preparing))
        XCTAssertFalse(machine.request(.failed))

        // failed 只能回 idle
        XCTAssertTrue(machine.request(.exiting))
        XCTAssertTrue(machine.request(.idle))
        XCTAssertTrue(machine.request(.preparing))
        XCTAssertTrue(machine.request(.failed))
        XCTAssertFalse(machine.request(.cleaning))
        XCTAssertFalse(machine.request(.exiting))
        XCTAssertTrue(machine.request(.idle))
    }

    func testExitIsIdempotentConceptually() {
        // exiting 只接受 idle；重复 exiting 会被上层 guard 拦截（§9 幂等）
        var machine = CleaningStateMachine()
        XCTAssertTrue(machine.request(.preparing))
        XCTAssertTrue(machine.request(.cleaning))
        XCTAssertTrue(machine.request(.exiting))
        XCTAssertFalse(machine.request(.exiting))
        XCTAssertFalse(machine.request(.cleaning))
        XCTAssertTrue(machine.request(.idle))
    }
}
