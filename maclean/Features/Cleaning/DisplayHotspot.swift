import AppKit
import CoreGraphics
import Foundation

/// 退出热区（用户 2026-11-11 决策，覆盖开发文档 §5.1"右上角"）：
/// **热区 = 屏幕正中央的 HUD 区域**。HUD 就写着"悬停即可退出"，
/// 用户会直接去悬停它，无需猜测热区位置。
/// 热区矩形与 CleaningHUDManager.hudFrame 使用同一公式，保证"看见的即悬停的"。
struct DisplayHotspot: Equatable {
    let displayID: CGDirectDisplayID
    let rect: CGRect

    init(displayID: CGDirectDisplayID, rect: CGRect) {
        self.displayID = displayID
        self.rect = rect
    }

    /// 从屏幕 frame 计算中央 HUD 热区（开发文档 §5.2 坐标系规则不变）。
    static func make(screen: NSScreen) -> DisplayHotspot? {
        guard let displayID = screen.cleaningDisplayID else { return nil }
        return DisplayHotspot(
            displayID: displayID,
            rect: rect(for: screen.frame)
        )
    }

    /// 纯几何计算，可单元测试。AppKit 全局坐标，y 向上，兼容负坐标屏幕（文档 §5.2）。
    /// 与 HUD 面板的摆放完全一致（屏幕正中央，尺寸 = hudSize）。
    static func rect(for frame: CGRect,
                     width: CGFloat = AppConstants.hudSize.width,
                     height: CGFloat = AppConstants.hudSize.height) -> CGRect {
        CGRect(
            x: frame.midX - width / 2,
            y: frame.midY - height / 2,
            width: width,
            height: height
        )
    }

    func contains(_ point: CGPoint) -> Bool {
        rect.contains(point)
    }
}
