import AppKit
import Foundation

/// 清洁模式状态（开发文档 §3）。hovering 携带触发显示器与开始时间。
enum CleaningState: Equatable {
    /// 未进入清洁模式
    case idle
    /// 检查能力、创建资源，尚未正式进入
    case preparing
    /// 黑屏运行，鼠标不在热区
    case cleaning
    /// 鼠标正在某块显示器的热区内连续悬停
    case hovering(displayID: CGDirectDisplayID, startedAt: CFTimeInterval)
    /// 停止监听并关闭窗口
    case exiting
    /// 进入或运行失败，回滚资源后返回 idle
    case failed
}

/// 清洁模式状态机（开发文档 §3 转换表）。纯逻辑、可单元测试。
///
/// 全局清洁状态只能由 CleaningManager 持有与驱动；其他模块上报事件。
struct CleaningStateMachine: Equatable {
    private(set) var state: CleaningState = .idle

    /// 请求状态转换。非法转换返回 false 且不改变状态（文档 §3 规则）。
    mutating func request(_ next: CleaningState) -> Bool {
        let allowed: Bool
        switch (state, next) {
        case (.idle, .preparing):
            allowed = true
        case (.preparing, .cleaning), (.preparing, .failed):
            allowed = true
        case (.cleaning, .hovering), (.cleaning, .exiting):
            allowed = true
        case (.hovering, .cleaning), (.hovering, .exiting):
            allowed = true
        case (.hovering, .hovering):
            // 跨屏热区切换：重新计时（文档 §1.7、§5.3）
            allowed = true
        case (.exiting, .idle), (.failed, .idle):
            allowed = true
        default:
            allowed = false
        }
        guard allowed else { return false }
        state = next
        return true
    }
}
