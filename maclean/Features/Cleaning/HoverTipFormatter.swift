import Foundation

/// 悬停提示文案格式化。纯逻辑，可单元测试。
enum HoverTipFormatter {
    /// 时长显示：整数不带小数（2 → "2"），其余保留一位小数（1.5 → "1.5"）
    static func secondsText(_ duration: Double) -> String {
        String(format: "%g", (duration * 10).rounded() / 10)
    }

    /// 中央提示文案："悬停 1.5 秒即可退出"
    static func tipText(_ duration: Double) -> String {
        "悬停 \(secondsText(duration)) 秒即可退出"
    }
}
