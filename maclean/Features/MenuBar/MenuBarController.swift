import AppKit
import SwiftUI

/// 菜单栏状态项与下拉面板（文档 §2.1 信息架构）。
///
/// NSStatusItem + NSPopover（SwiftUI 定制卡片 MenuBarPanelView）：
/// - 原生 NSMenu 不支持视觉定制且部分系统版本丢图标；
/// - `.transient` 弹出行为与原生菜单一致（点击外部自动关闭）；
/// - 执行动作前先收起面板，避免清洁黑屏盖在面板下。
@MainActor
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let environment = AppEnvironment.shared

    /// 创建状态项与弹出面板（applicationDidFinishLaunching 时调用一次）。
    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(named: "MenuBarTemplate")   // logo 派生的 Template 图标
            image?.isTemplate = true
            button.image = image
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPanelView(
                onSleep: { [weak self] in
                    self?.closeThen { self?.environment.displaySleep.sleepNow { error in
                        if let error { AlertPresenter.show(error) }
                    } }
                },
                onClean: { [weak self] in
                    self?.closeThen { self?.environment.cleaning.enter() }
                },
                onSettings: { [weak self] in
                    self?.closeThen { self?.environment.settingsWindow.showSettings() }
                },
                onAbout: { [weak self] in
                    self?.closeThen {
                        NSApp.activate(ignoringOtherApps: true)
                        NSApp.orderFrontStandardAboutPanel(options: [:])
                    }
                },
                onQuit: {
                    NSApp.terminate(nil)
                }
            )
        )

        statusItem = item
        Log.app.notice("状态项已创建（NSPopover 定制面板）")
    }

    /// 面板打开即记日志：远程确认用户点开的是本实例的入口（排障用）。
    private func showPopover(relativeTo button: NSButton) {
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        Log.app.notice("下拉面板已打开")
    }

    private func closeThen(_ action: @escaping () -> Void) {
        popover.performClose(nil)
        action()
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover(relativeTo: button)
        }
    }
}
