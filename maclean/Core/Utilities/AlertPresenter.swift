import AppKit
import Foundation

/// 统一的错误弹窗（文档 §6.1：明确、简短的中文；权限拒绝后提供设置引导）。
enum AlertPresenter {
    @MainActor
    static func show(_ error: MacleanError) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = error.title
        alert.informativeText = error.message
        alert.alertStyle = .warning

        if error.opensAccessibilitySettings {
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "取消")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(KeyboardEventMonitor.accessibilitySettingsURL)
            }
        } else {
            alert.addButton(withTitle: "好")
            alert.runModal()
        }
    }
}
