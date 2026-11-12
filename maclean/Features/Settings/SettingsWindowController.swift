import AppKit
import SwiftUI

/// 设置窗口：自建 NSWindow 承载 SwiftUI SettingsView。
///
/// 弃用「SwiftUI Settings 场景 + showSettingsWindow: selector」的组合：
/// 该 selector 在新系统版本上不存在，sendAction 静默失败导致设置页无法打开
/// （2026-11-11 用户实测）。自建窗口行为完全可控。
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    /// 打开（或前置已存在的）设置窗口。
    func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 240),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "maclean 设置"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        Log.settings.notice("设置窗口已打开（自建 NSWindow）")
    }
}
