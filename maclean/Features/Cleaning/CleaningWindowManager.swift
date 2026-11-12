import AppKit
import CoreGraphics
import Foundation

/// 多显示器黑屏窗口管理（开发文档 §4）。
///
/// - 一块显示器一个独立 borderless NSWindow（§4.1），不创建横跨所有显示器的大窗口。
/// - 用 CGDirectDisplayID 作 key（§4.2），不用数组下标。
/// - 事务式进入：prepareWindows() 先创建但不展示，showAll() 统一展示（§8）。
/// - 创建中途失败必须回滚已创建窗口（§4.3）。
/// - 层级 .screenSaver，需在目标系统实测（§4.3/§4.4）。
@MainActor
final class CleaningWindowManager {
    private var windows: [CGDirectDisplayID: NSWindow] = [:]

    var windowCount: Int { windows.count }

    /// 当前窗口覆盖的显示器 ID（HUD 同步用）
    var displayIDs: [CGDirectDisplayID] { Array(windows.keys) }

    /// 创建所有黑屏窗口但暂不展示。任一失败即关闭已创建窗口并抛错（§4.3、§8）。
    func prepareWindows() throws {
        closeAll()

        let screens = Self.activeScreens()
        guard !screens.isEmpty else {
            throw MacleanError.windowCreationFailed("未找到活动显示器")
        }

        for screen in screens {
            guard let displayID = screen.cleaningDisplayID else {
                closeAll()
                throw MacleanError.windowCreationFailed("显示器 displayID 获取失败（§11）")
            }
            windows[displayID] = makeWindow(for: screen)
        }
        guard !windows.isEmpty else {
            throw MacleanError.windowCreationFailed("未能创建任何黑屏窗口")
        }
        Log.cleaning.notice("黑屏窗口已准备：\(self.windows.count) 块显示器（未展示）")
    }

    /// 统一展示所有黑屏窗口（开发文档 §8 第 8 步）。带短淡入（键盘过滤此时已生效）。
    func showAll() {
        for (_, window) in windows {
            window.alphaValue = 0
            window.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = AppConstants.fadeDuration
            for (_, window) in windows {
                window.animator().alphaValue = 1
            }
        })
        Log.cleaning.notice("黑屏窗口已全部展示：\(self.windows.count) 块")
    }

    /// 关闭并释放全部窗口。幂等（开发文档 §4.3、§9）。
    func closeAll() {
        guard !windows.isEmpty else { return }
        for (_, window) in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
        Log.cleaning.notice("黑屏窗口已全部关闭")
    }

    /// 退出视觉收尾：淡出后关闭。字典立即清空（重复退出/快速重进安全），
    /// 键盘恢复由 manager 在调用前同步完成，淡出纯视觉。
    func fadeOutAndClose(duration: TimeInterval = AppConstants.fadeDuration) {
        guard !windows.isEmpty else { return }
        let closing = windows
        windows.removeAll()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            for (_, window) in closing {
                window.animator().alphaValue = 0
            }
        }, completionHandler: {
            for (_, window) in closing {
                window.orderOut(nil)
                window.close()
            }
        })
        Log.cleaning.notice("黑屏窗口淡出关闭：\(closing.count) 块")
    }

    /// 显示器热插拔/布局变化后的窗口同步（开发文档 §10）：
    /// 新增补建并展示、移除关闭、布局变化更新 frame。
    func handleDisplayConfigurationChanged() {
        guard !windows.isEmpty else { return }
        let screens = Self.activeScreens()
        let activeIDs = Set(screens.compactMap { $0.cleaningDisplayID })

        // 移除已消失的显示器窗口（§10）
        for displayID in windows.keys where !activeIDs.contains(displayID) {
            Log.cleaning.notice("显示器已移除，关闭对应窗口：\(displayID)")
            windows[displayID]?.orderOut(nil)
            windows[displayID]?.close()
            windows.removeValue(forKey: displayID)
        }

        // 新增显示器：创建并立即展示；布局变化：更新 frame
        for screen in screens {
            guard let displayID = screen.cleaningDisplayID else { continue }
            if let existing = windows[displayID] {
                if existing.frame != screen.frame {
                    existing.setFrame(screen.frame, display: true)
                }
            } else {
                Log.cleaning.notice("发现新增显示器，创建窗口：\(displayID)")
                let window = makeWindow(for: screen)
                window.orderFrontRegardless()
                windows[displayID] = window
            }
        }
    }

    // MARK: - 内部

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen   // §4.3：绑定到目标显示器
        )
        window.backgroundColor = .black
        window.isOpaque = true
        window.hasShadow = false
        window.ignoresMouseEvents = true   // 热区检测走全局鼠标采样
        window.level = .screenSaver        // §4.3：目标系统需实测
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.restorationClass = nil

        // 纯黑内容视图：无任何 UI（文档 §1.3）
        let background = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor.black.cgColor
        background.autoresizingMask = [.width, .height]
        window.contentView = background
        return window
    }

    /// 当前显示器集合。镜像模式下同 frame 只保留一块（开发文档 §4.2 场景）。
    static func activeScreens() -> [NSScreen] {
        var seenFrames: [CGRect] = []
        return NSScreen.screens.filter { screen in
            if seenFrames.contains(screen.frame) { return false }
            seenFrames.append(screen.frame)
            return true
        }
    }
}
