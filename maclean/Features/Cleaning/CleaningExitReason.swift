import Foundation

/// 清洁模式统一退出原因（开发文档 §9）。所有退出路径都走 exitCleaningMode(reason:)。
enum CleaningExitReason: String {
    /// 悬停计时完成（正常退出）
    case hoverCompleted
    /// EventTap 创建失败/持续失效
    case eventTapUnavailable
    /// 显示器配置异常
    case displayConfigurationFailure
    /// 应用即将退出
    case applicationWillTerminate
    /// 内部错误 / 不可控状态（§1.10 安全恢复）
    case internalError
    /// 达到单次最长清洁时长
    case maxDurationExceeded
}
