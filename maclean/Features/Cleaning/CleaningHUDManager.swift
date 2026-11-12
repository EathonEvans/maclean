import AppKit
import Foundation
import SwiftUI

/// 屏幕中央 HUD 管理器。
///
/// 显示规则（用户 2026-11-11 决策，覆盖开发文档 §1.3/§6.1 的"默认隐藏"）：
/// **进入清洁模式后 HUD 常驻显示**——隐藏后用户无从得知退出方式。
/// - 每块活动显示器的屏幕正中央各一个 HUD（开发文档 §6.3 定位）。
/// - 独立透明 NSPanel，ignoresMouseEvents = true，绝不干扰热区检测（§6.1）。
/// - 层级在黑屏窗口（.screenSaver）之上。
/// - 进度路由：悬停哪块屏，哪块屏的进度条增长；离开后所有进度归零（§1.6）。
/// - 热区与 HUD 摆放同公式（DisplayHotspot.rect == hudFrame），看见的即悬停的。
@MainActor
final class CleaningHUDManager {
    private struct PanelBox {
        let panel: NSPanel
        let model: CleaningHUDModel
    }

    private var panels: [CGDirectDisplayID: PanelBox] = [:]
    /// 当前悬停的显示器（进度路由目标）；nil = 未悬停
    private(set) var activeDisplayID: CGDirectDisplayID?

    var isVisible: Bool { !panels.isEmpty }

    /// 让 HUD 集合与显示器集合精确同步（进入时、显示器变化后、屏幕唤醒后调用）。
    /// 常驻显示；已有面板位置漂移时重新摆位（如显示器睡眠唤醒后）。
    func syncDisplays(for displayIDs: [CGDirectDisplayID], text: String) {
        let target = Set(displayIDs)

        // 移除已消失显示器的面板
        for displayID in panels.keys where !target.contains(displayID) {
            panels[displayID]?.panel.orderOut(nil)
            panels[displayID]?.panel.close()
            panels.removeValue(forKey: displayID)
        }

        // 为新增显示器创建面板；已有面板刷新文案与位置
        for displayID in displayIDs {
            if let box = panels[displayID] {
                box.model.text = text
                if let screen = Self.screen(for: displayID) {
                    let desired = Self.hudFrame(size: AppConstants.hudWindowSize, on: screen)
                    if box.panel.frame != desired {
                        box.panel.setFrame(desired, display: true)
                    }
                }
                continue
            }
            guard let screen = Self.screen(for: displayID) else { continue }
            let model = CleaningHUDModel(text: text)
            guard let panel = makePanel(model: model, screen: screen) else { continue }
            panels[displayID] = PanelBox(panel: panel, model: model)
            panel.orderFrontRegardless()
        }
        Log.cleaning.notice("HUD 常驻显示：\(self.panels.count) 块显示器")
    }

    /// 设置当前悬停的显示器（进入/切换热区）。切换时所有进度归零、悬停态迁移。
    func setActiveDisplay(_ displayID: CGDirectDisplayID?) {
        activeDisplayID = displayID
        for (id, box) in panels {
            box.model.isHovered = (id == displayID)
            box.model.progress = 0
            box.model.isCompleted = false
        }
    }

    /// 更新当前悬停显示器的进度（0…1）。
    func updateProgress(_ progress: Double) {
        guard let activeDisplayID,
              let box = panels[activeDisplayID] else { return }
        box.model.progress = progress
    }

    /// 计时完成：高亮一拍（随后由 manager 延迟触发统一退出，随整体淡出）。
    func markCompleted() {
        guard let activeDisplayID,
              let box = panels[activeDisplayID] else { return }
        box.model.progress = 1
        box.model.isCompleted = true
    }

    /// 所有 HUD 进度归零（离开热区，开发文档 §1.6）。
    func resetProgresses() {
        for (_, box) in panels {
            box.model.progress = 0
        }
    }

    /// 淡出后关闭全部面板（退出清洁模式的视觉收尾）。
    /// 面板字典立即清空：重复退出或快速重进都安全。
    func fadeOutAndShutdown(duration: TimeInterval = AppConstants.fadeDuration) {
        guard !panels.isEmpty else { return }
        let closing = panels
        panels.removeAll()
        activeDisplayID = nil
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            for (_, box) in closing {
                box.panel.animator().alphaValue = 0
            }
        }, completionHandler: {
            for (_, box) in closing {
                box.panel.orderOut(nil)
                box.panel.close()
            }
        })
    }

    // MARK: - 内部

    private func makePanel(model: CleaningHUDModel, screen: NSScreen) -> NSPanel? {
        // 面板比卡片大一圈（投影/光晕余量）；卡片与热区都用 hudSize 居中，两者始终对齐
        let panel = NSPanel(
            contentRect: Self.hudFrame(size: AppConstants.hudWindowSize, on: screen),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true   // §6.1：HUD 不接收鼠标事件
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(
            rootView: CleaningHUDView(model: model)
        )
        return panel
    }

    /// HUD 位于屏幕正中央（开发文档 §6.3）。纯函数，可单元测试。
    nonisolated static func hudFrame(size: CGSize, in screenFrame: CGRect) -> CGRect {
        CGRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    static func hudFrame(size: CGSize, on screen: NSScreen) -> CGRect {
        hudFrame(size: size, in: screen.frame)
    }

    static func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { $0.cleaningDisplayID == displayID }
    }
}
