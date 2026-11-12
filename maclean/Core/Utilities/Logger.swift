import Foundation
import os

/// 统一日志入口。
/// 隐私红线（文档 §6.2）：只记录状态、错误码和必要系统信息，绝不记录键盘内容或鼠标轨迹。
enum Log {
    static let app = Logger(subsystem: AppConstants.subsystem, category: "app")
    static let cleaning = Logger(subsystem: AppConstants.subsystem, category: "cleaning")
    static let displaySleep = Logger(subsystem: AppConstants.subsystem, category: "displaySleep")
    static let input = Logger(subsystem: AppConstants.subsystem, category: "input")
    static let display = Logger(subsystem: AppConstants.subsystem, category: "display")
    static let settings = Logger(subsystem: AppConstants.subsystem, category: "settings")
}
