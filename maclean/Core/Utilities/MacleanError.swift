import Foundation

/// 面向用户的统一错误。文案使用明确、简短的中文（文档 §6.1）。
enum MacleanError: LocalizedError {
    /// 清洁模式需要辅助功能权限（键盘过滤）
    case accessibilityPermissionNeeded
    /// CGEventTap 创建失败
    case eventTapCreationFailed(String)
    /// 清洁窗口创建失败
    case windowCreationFailed(String)
    /// 息屏指令执行失败
    case displaySleepFailed(String)

    var title: String {
        switch self {
        case .accessibilityPermissionNeeded:
            return "需要辅助功能权限"
        case .eventTapCreationFailed, .windowCreationFailed:
            return "清洁模式初始化失败"
        case .displaySleepFailed:
            return "息屏失败"
        }
    }

    var message: String {
        switch self {
        case .accessibilityPermissionNeeded:
            // 文档 §4.7：过滤初始化失败时，不能让用户误以为键盘已被锁定。
            // 附注旧签名残留条目的处理方法（列表显示已开启但实际不生效的典型场景）。
            return "屏蔽键盘输入需要「辅助功能」权限。请在 系统设置 > 隐私与安全性 > 辅助功能 中允许 maclean。\n若列表中 maclean 已显示开启但仍提示此消息，请先选中它按「−」移除，然后重新点击「清洁」并重新允许。"
        case .eventTapCreationFailed(let detail):
            return "键盘过滤初始化失败，已取消进入清洁模式，键盘未被屏蔽。(\(detail))"
        case .windowCreationFailed(let detail):
            return "无法创建清洁窗口，已回滚到正常桌面。(\(detail))"
        case .displaySleepFailed(let detail):
            return "显示器休眠指令执行失败：\(detail)"
        }
    }

    /// 是否应附带「打开系统设置」按钮
    var opensAccessibilitySettings: Bool {
        if case .accessibilityPermissionNeeded = self { return true }
        return false
    }
}
