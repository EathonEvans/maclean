import XCTest
@testable import maclean

/// EventTap 生命周期回归：进入/退出清洁模式反复循环（开发文档 §12.3
/// "多次进入退出，不出现重复监听器"）。回归 2026-11-11 bug：
/// stop() 置位 stopRequested 后未复位，第二次进入报"monitor 已停止，无法复用"。
@MainActor
final class KeyboardEventMonitorCycleTests: XCTestCase {
    func testStartStopCycleIsRepeatable() {
        let monitor = KeyboardEventMonitor()
        var outcomes: [KeyboardEventMonitor.StartOutcome] = []

        let first = expectation(description: "start #1")
        monitor.start { outcome in
            outcomes.append(outcome)
            first.fulfill()
        }
        wait(for: [first], timeout: 10)

        monitor.stop()

        let second = expectation(description: "start #2")
        monitor.start { outcome in
            outcomes.append(outcome)
            second.fulfill()
        }
        wait(for: [second], timeout: 10)

        monitor.stop()

        // 关键回归断言：任何一次都不得报"无法复用"
        for outcome in outcomes {
            if case .failure(let error) = outcome {
                XCTAssertFalse(
                    error.message.contains("无法复用"),
                    "第二次进入不得报无法复用（stop 标志未复位）：\(error.message)"
                )
            }
        }

        // 两次结果类别应一致：环境无授权则两次都失败授权；有授权则两次都成功
        func isAccessFailure(_ outcome: KeyboardEventMonitor.StartOutcome?) -> Bool {
            if case .failure(.accessibilityPermissionNeeded) = outcome { return true }
            return false
        }
        XCTAssertEqual(
            isAccessFailure(outcomes.first),
            isAccessFailure(outcomes.last),
            "start/stop 循环后的行为应与首次一致：outcomes=\(outcomes)"
        )
    }

    func testTripleCycleStaysConsistent() {
        let monitor = KeyboardEventMonitor()
        var outcomes: [KeyboardEventMonitor.StartOutcome] = []

        for round in 1...3 {
            let exp = expectation(description: "start #\(round)")
            monitor.start { outcome in
                outcomes.append(outcome)
                exp.fulfill()
            }
            wait(for: [exp], timeout: 10)
            monitor.stop()
        }

        XCTAssertEqual(outcomes.count, 3)
        for outcome in outcomes {
            if case .failure(let error) = outcome {
                XCTAssertFalse(error.message.contains("无法复用"))
            }
        }
    }
}
