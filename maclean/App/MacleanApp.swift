import SwiftUI

@main
struct MacleanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 菜单栏入口由 AppDelegate 的 NSStatusItem 提供（图标渲染可控，见 MenuBarController）；
        // 这里只保留设置窗口场景。
        Settings {
            SettingsView()
        }
    }
}
