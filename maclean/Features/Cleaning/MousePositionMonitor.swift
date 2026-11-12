import AppKit
import CoreGraphics
import Foundation
import QuartzCore

/// 鼠标位置采样、热区判定与连续悬停计时（开发文档 §5）。
///
/// - 主线程 30Hz Timer（.common 模式）采样 `NSEvent.mouseLocation`；
///   EventTap 的鼠标事件可作为额外采样信号，最终走同一个 sample() 状态机（§5.5 注 4）。
/// - 计时基于单调时钟 CACurrentMediaTime（§5.4），绝不按 Timer 触发次数累计。
/// - 连续停留语义（§5.3）：进入热区开始计时；离开哪怕一个采样周期也立即归零；
///   跨屏热区切换视为"离开 A、进入 B"，重新计时。
/// - 完成回调前先停止采样，避免重复触发（§5.5 注 2）。
@MainActor
final class MousePositionMonitor {
    private struct HoverTarget {
        let displayID: CGDirectDisplayID
        let startedAt: CFTimeInterval
    }

    // MARK: - 事件语义（开发文档 §5.6）

    /// 进入某显示器热区（协调器应在该屏中央显示 HUD 并进入 hovering）
    var onEnter: ((CGDirectDisplayID) -> Void)?
    /// 离开所有热区（隐藏 HUD、进度清零、回到 cleaning）
    var onLeave: (() -> Void)?
    /// 当前悬停进度 0…1
    var onProgress: ((Double) -> Void)?
    /// 同一热区连续停留达到悬停时长（统一退出）
    var onCompleted: (() -> Void)?
    /// 每次采样的原始位置（诊断用）
    var onSample: ((CGPoint) -> Void)?

    /// 悬停时长（秒），默认 1.5，可由设置调整
    var hoverDuration: TimeInterval = AppConstants.defaultHoverDuration
    /// 单调时钟（可注入以便单元测试；生产为 CACurrentMediaTime）
    var now: () -> CFTimeInterval = CACurrentMediaTime

    private(set) var hotspots: [DisplayHotspot] = []
    private var activeTarget: HoverTarget?
    private var timer: Timer?
    private(set) var isRunning = false

    // MARK: - 生命周期

    func start() {
        guard timer == nil else { return }
        rebuildHotspots()
        let timer = Timer(timeInterval: AppConstants.mousePollInterval, repeats: true) { [weak self] _ in
            self?.sample()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        isRunning = true
        Log.cleaning.notice("鼠标采样已启动：热区 \(self.hotspots.count) 个，时长 \(Int(self.hoverDuration * 10) / 10)s")
    }

    /// 停止采样并清空悬停状态。幂等（开发文档 §5.5 stop）。
    func stop() {
        timer?.invalidate()
        timer = nil
        activeTarget = nil
        hotspots.removeAll()
        isRunning = false
    }

    /// 重建热区（显示器拓扑变化后必须重建，§5.5 注 3、§10）。
    /// 当前悬停目标失效时触发 onLeave。
    func displaysDidChange(screens: [NSScreen] = NSScreen.screens) {
        rebuildHotspots(screens: screens)
        if activeTarget != nil {
            activeTarget = nil
            onLeave?()
        }
    }

    /// 采样一次。`point` 为 nil 时取全局鼠标位置；测试/自检可注入合成坐标。
    func sample(at point: CGPoint? = nil) {
        guard isRunning else { return }
        let location = point ?? NSEvent.mouseLocation
        onSample?(location)

        var target = hotspots.first { $0.contains(location) }

        // 滞后带（用户 2026-11-11 批准，放宽 §5.3 的严格重置）：
        // 已有悬停目标时，其外扩 hotspotHysteresis 的范围仍视为"在热区内"，
        // 避免鼠标在边缘来回蹭导致进度反复清零。
        if target == nil, let active = activeTarget,
           let activeHotspot = hotspots.first(where: { $0.displayID == active.displayID }) {
            let expanded = activeHotspot.rect.insetBy(
                dx: -AppConstants.hotspotHysteresis,
                dy: -AppConstants.hotspotHysteresis
            )
            if expanded.contains(location) {
                target = activeHotspot
            }
        }

        guard let target else {
            // 位于所有热区之外：计时归零、cleaning
            if activeTarget != nil {
                activeTarget = nil
                onLeave?()
            }
            return
        }

        // 跨屏切换：先离开旧目标、再进入新目标，旧进度不得继承（§5.6、§1.7）
        if let old = activeTarget, old.displayID != target.displayID {
            activeTarget = nil
            onLeave?()
        }
        if activeTarget == nil {
            activeTarget = HoverTarget(displayID: target.displayID, startedAt: now())
            onEnter?(target.displayID)
        }

        guard let activeTarget else { return }

        let elapsed = now() - activeTarget.startedAt
        let progress = min(max(elapsed / hoverDuration, 0), 1)
        onProgress?(progress)

        if elapsed >= hoverDuration {
            // 完成回调前先停止采样，避免重复触发（§5.5 注 2）
            stop()
            onCompleted?()
        }
    }

    /// EventTap 鼠标事件信号（CG 坐标）→ 统一采样。坐标转换见 §5.2。
    func noteTapMouseMoved(cgLocation: CGPoint, primaryHeight: CGFloat) {
        sample(at: Self.appKitPoint(fromCG: cgLocation, primaryHeight: primaryHeight))
    }

    /// CG 全局坐标（主屏左上原点，y 向下）→ AppKit 全局坐标（主屏左下原点，y 向上）。
    /// 纯函数，可单元测试（开发文档 §5.2：不可混用未经转换的 CG 坐标）。
    nonisolated static func appKitPoint(fromCG point: CGPoint, primaryHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    /// 仅测试/自检使用：直接安装热区（绕过 NSScreen 构造）。
    func installHotspotsForTesting(_ spots: [DisplayHotspot]) {
        hotspots = spots
    }

    /// 仅测试使用：直接控制采样运行状态。
    var isRunningForTesting: Bool {
        get { isRunning }
        set { isRunning = newValue }
    }

    // MARK: - 内部

    private func rebuildHotspots(screens: [NSScreen] = NSScreen.screens) {
        // 镜像模式下同 frame 屏幕去重，避免重复热区（文档 §4.2 用 displayID 作 key）
        var seenFrames: [CGRect] = []
        hotspots = screens
            .filter { screen in
                if seenFrames.contains(screen.frame) { return false }
                seenFrames.append(screen.frame)
                return true
            }
            .compactMap { DisplayHotspot.make(screen: $0) }
    }
}
