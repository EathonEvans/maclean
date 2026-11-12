import AppKit
import CoreGraphics
import Foundation

/// 清洁模式协调器（开发文档 §2、§8、§9）。
///
/// 全局清洁状态只能由本模块管理；其他模块上报事件，不直接修改全局状态。
///
/// 进入采用"先准备、后展示"的事务式流程（§8）：
/// preparing → 检查权限 → 创建 EventTap（专用线程，主线程有界等待）→
/// 创建黑屏窗口（不展示）→ HUD/热区准备 → 展示窗口 → 启动鼠标采样 → cleaning。
/// 任一步失败回滚已创建资源并回到 idle，向用户展示可理解的错误。
///
/// 所有退出统一走 exitCleaningMode(reason:)（§9），幂等。
///
/// 安全兜底（§1.10：不能留下无法退出的黑屏）：
/// ⌘⌥Esc 紧急退出、EventTap 失效自动退出、最长 10 分钟自动退出、
/// 主线程看门狗（后台 ping，主线程失联约 1 分钟强制退出进程）。
@MainActor
final class CleaningManager: ObservableObject {
    @Published private(set) var state: CleaningState = .idle

    /// 初始化失败的用户提示回调
    var errorHandler: ((MacleanError) -> Void)?

    private var machine = CleaningStateMachine()
    private let settings: SettingsManager
    private let keyboardFilter = KeyboardEventMonitor()
    private let windowManager = CleaningWindowManager()
    private let hudManager = CleaningHUDManager()
    private let mouseMonitor = MousePositionMonitor()
    private let displayMonitor = DisplayMonitor()

    /// 进入 cleaning 的单调时间（时长上限用）
    private var cleaningBeganAt: CFTimeInterval?
    /// 节流诊断的上次时间（CACurrentMediaTime 秒）
    private var lastDiagnosticsAt: CFTimeInterval = 0
    /// 主线程看门狗
    private var watchdogTimer: DispatchSourceTimer?
    private let watchdogLock = NSLock()
    private var cleaningActiveFlag = false
    private var watchdogMisses = 0

    init(settings: SettingsManager) {
        self.settings = settings
    }

    // MARK: - 进入（开发文档 §8 事务式流程）

    func enter() {
        guard state == .idle else {
            Log.cleaning.notice("忽略进入请求：当前状态 \(self.stateText, privacy: .public)")
            return
        }
        transition(.preparing)

        // 事件接线（monitor 上报，manager 改状态；§2 规则）
        mouseMonitor.onEnter = { [weak self] displayID in
            guard let self else { return }
            if self.machine.request(.hovering(displayID: displayID, startedAt: CACurrentMediaTime())) {
                self.state = self.machine.state
                self.hudManager.setActiveDisplay(displayID)   // 进度路由到该屏 HUD
                Log.cleaning.notice("进入热区（显示器 \(displayID)），开始悬停计时")
            }
        }
        mouseMonitor.onLeave = { [weak self] in
            guard let self else { return }
            if self.machine.request(.cleaning) {
                self.state = self.machine.state
                self.hudManager.setActiveDisplay(nil)   // 所有进度归零（HUD 保持常驻）
                Log.cleaning.notice("离开热区，计时已归零")
            }
        }
        mouseMonitor.onProgress = { [weak self] progress in
            self?.hudManager.updateProgress(progress)
            self?.checkMaxDuration()
        }
        mouseMonitor.onCompleted = { [weak self] in
            guard let self else { return }
            // 满格高亮一拍再退出（体验打磨：给"完成"一个可见的确认）
            self.hudManager.markCompleted()
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.completedFlashDuration) {
                self.exitCleaningMode(reason: .hoverCompleted)
            }
        }
        mouseMonitor.onSample = { [weak self] point in
            self?.handleSample(point)
        }
        keyboardFilter.onBroken = { [weak self] in
            self?.exitCleaningMode(reason: .eventTapUnavailable)
        }
        displayMonitor.onConfigurationChanged = { [weak self] in
            self?.handleDisplayConfigurationChanged()
        }
        displayMonitor.onScreensWake = { [weak self] in
            self?.handleScreensWake()
        }

        displayMonitor.start()

        // §8 第 4 步：先创建 EventTap（专用线程，主线程最多等待 2 秒）
        Log.cleaning.notice("开始进入清洁模式：创建输入过滤 tap（主线程最多等待 \(Int(AppConstants.tapStartMainThreadWait)) 秒）")
        keyboardFilter.start { [weak self] outcome in
            self?.handleFilterStartOutcome(outcome)
        }
    }

    /// tap 创建结果（主线程）。
    private func handleFilterStartOutcome(_ outcome: KeyboardEventMonitor.StartOutcome) {
        // 等待期间已被退出/终止：回收残留资源
        guard state == .preparing else {
            keyboardFilter.stop()
            return
        }
        switch outcome {
        case .success:
            finishPreparation()
        case .failure(let error):
            fail(error)
        }
    }

    /// §8 第 5-10 步：窗口（不展示）→ 展示 → 鼠标采样 → cleaning。
    private func finishPreparation() {
        do {
            try windowManager.prepareWindows()
        } catch {
            fail(toMacleanError(error))
            return
        }

        // §8 第 7 步：确认显示器清单（prepareWindows 内部已按当前 screens 构建）

        // §8 第 8 步：统一展示
        windowManager.showAll()

        // HUD 常驻显示（用户 2026-11-11 决策，覆盖文档 §1.3/§6.1）：
        // 黑屏出现的同时，每块屏中央即可见退出提示
        hudManager.syncDisplays(
            for: windowManager.displayIDs,
            text: HoverTipFormatter.tipText(settings.effectiveHoverDuration)
        )

        // §8 第 9 步：启动鼠标采样
        mouseMonitor.hoverDuration = settings.effectiveHoverDuration
        mouseMonitor.start()

        // §8 第 10 步：正式进入
        cleaningBeganAt = CACurrentMediaTime()
        transition(.cleaning)
        startWatchdog()
        Log.cleaning.notice("已进入清洁模式：\(self.windowManager.windowCount) 块显示器，键盘过滤已启用；悬停中央提示框退出")
    }

    // MARK: - 退出（开发文档 §9，统一入口，幂等）

    func exitCleaningMode(reason: CleaningExitReason) {
        guard state != .exiting, state != .idle, state != .failed else { return }
        transition(.exiting)

        // §9：输入恢复是关键步骤，必须同步先行（键盘过滤停止 = 键盘立即恢复）
        mouseMonitor.stop()
        keyboardFilter.stop()

        // 视觉收尾（淡出为异步纯视觉，状态立即回 idle）
        hudManager.fadeOutAndShutdown()
        windowManager.fadeOutAndClose()
        displayMonitor.stop()
        stopWatchdog()
        cleaningBeganAt = nil
        lastDiagnosticsAt = 0

        transition(.idle)
        Log.cleaning.notice("已退出清洁模式（原因：\(reason.rawValue, privacy: .public)），键盘输入已恢复")
    }

    /// 应用正常退出前的资源释放（文档 §9：applicationWillTerminate）。
    func shutdownForTermination() {
        if state != .idle {
            exitCleaningMode(reason: .applicationWillTerminate)
        }
        keyboardFilter.stop()
        displayMonitor.stop()
    }

    // MARK: - 失败回滚（§8：任一步失败回滚已创建资源）

    private func fail(_ error: MacleanError) {
        if machine.request(.failed) {
            state = machine.state
        }
        mouseMonitor.stop()
        hudManager.fadeOutAndShutdown(duration: 0)   // 回滚不播动画，立即清理
        windowManager.closeAll()
        keyboardFilter.stop()
        displayMonitor.stop()
        stopWatchdog()
        cleaningBeganAt = nil
        lastDiagnosticsAt = 0

        if machine.request(.idle) {
            state = machine.state
        }
        Log.cleaning.error("清洁模式初始化失败并已回滚：\(error.title)")
        errorHandler?(error)
    }

    // MARK: - 采样诊断与时长上限

    private func handleSample(_ point: CGPoint) {
        guard state == .cleaning || (isHoveringState(state)) else { return }
        checkMaxDuration()
        emitDiagnostics(point: point)
    }

    private func checkMaxDuration() {
        guard let beganAt = cleaningBeganAt else { return }
        if CACurrentMediaTime() - beganAt >= AppConstants.maxCleaningDuration {
            Log.cleaning.notice("清洁时长达到上限 \(Int(AppConstants.maxCleaningDuration)) 秒，自动退出")
            exitCleaningMode(reason: .maxDurationExceeded)
        }
    }

    /// 节流诊断日志（.notice 持久化）：鼠标位置、热区判定，用于远程排障。
    private func emitDiagnostics(point: CGPoint) {
        let now = CACurrentMediaTime()
        if now - lastDiagnosticsAt < AppConstants.diagnosticsInterval {
            return
        }
        lastDiagnosticsAt = now
        let hotspots = mouseMonitor.hotspots
        let inside = hotspots.first { $0.contains(point) }?.displayID
        Log.cleaning.notice(
            "清洁诊断 mouse=(\(point.x, format: .fixed(precision: 1)), \(point.y, format: .fixed(precision: 1))) hotspots=\(hotspots.map { "\($0.displayID):\($0.rect)" }.joined(separator: " "), privacy: .public) inside=\(inside.map { String($0) } ?? "none", privacy: .public)"
        )
    }

    private func handleDisplayConfigurationChanged() {
        guard state == .cleaning || isHoveringState(state) else { return }
        // §10：重建热区（悬停目标被拔出会触发 onLeave → 计时清零），再同步窗口与 HUD
        mouseMonitor.displaysDidChange()
        windowManager.handleDisplayConfigurationChanged()
        hudManager.syncDisplays(
            for: windowManager.displayIDs,
            text: HoverTipFormatter.tipText(settings.effectiveHoverDuration)
        )
    }

    /// 显示器睡眠唤醒：窗口与 HUD 位置可能漂移，重新校准（§4.4 实测场景）。
    /// 悬停状态一并重置——唤醒后鼠标位置的可信度未知。
    private func handleScreensWake() {
        guard state == .cleaning || isHoveringState(state) else { return }
        Log.cleaning.notice("显示器唤醒，重新校准窗口与 HUD")
        mouseMonitor.displaysDidChange()
        windowManager.handleDisplayConfigurationChanged()
        hudManager.syncDisplays(
            for: windowManager.displayIDs,
            text: HoverTipFormatter.tipText(settings.effectiveHoverDuration)
        )
    }

    // MARK: - 主线程看门狗（§1.10 硬保证）

    /// 清洁期间后台 ping 主线程；连续失联即强制退出进程（释放全部窗口与 tap）。
    private func startWatchdog() {
        stopWatchdog()
        watchdogLock.lock()
        cleaningActiveFlag = true
        watchdogMisses = 0
        watchdogLock.unlock()

        let timer = DispatchSource.makeTimerSource(
            queue: DispatchQueue(label: "com.ethon.maclean.watchdog", qos: .utility)
        )
        timer.schedule(
            deadline: .now() + AppConstants.watchdogInterval,
            repeating: AppConstants.watchdogInterval
        )
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.watchdogLock.lock()
            let active = self.cleaningActiveFlag
            self.watchdogLock.unlock()
            guard active else { return }

            let pong = DispatchSemaphore(value: 0)
            DispatchQueue.main.async { pong.signal() }
            if pong.wait(timeout: .now() + AppConstants.watchdogPingTimeout) == .timedOut {
                self.watchdogLock.lock()
                self.watchdogMisses += 1
                let miss = self.watchdogMisses
                self.watchdogLock.unlock()
                Log.cleaning.error("看门狗：主线程无响应（第 \(miss) 次）")
                if miss >= AppConstants.watchdogMaxMisses {
                    Log.cleaning.fault("看门狗：主线程持续无响应，强制退出进程以解除清洁锁定")
                    Darwin.exit(0)
                }
            } else {
                self.watchdogLock.lock()
                self.watchdogMisses = 0
                self.watchdogLock.unlock()
            }
        }
        timer.resume()
        watchdogTimer = timer
    }

    private func stopWatchdog() {
        watchdogTimer?.cancel()
        watchdogTimer = nil
        watchdogLock.lock()
        cleaningActiveFlag = false
        watchdogMisses = 0
        watchdogLock.unlock()
    }

    // MARK: - 自检支持（仅 -macleanCleaningSelfTest 使用）

    /// 注入合成采样点（自检模式验证热区→计时→退出全管线）。
    func debugInjectSample(at point: CGPoint) {
        mouseMonitor.sample(at: point)
    }

    // MARK: - 辅助

    private func transition(_ next: CleaningState) {
        guard machine.request(next) else {
            Log.cleaning.fault("非法状态转换：当前 \(self.stateText, privacy: .public) → \(self.nextText(next), privacy: .public)")
            assertionFailure("非法清洁状态转换")
            return
        }
        state = machine.state
    }

    private func isHoveringState(_ state: CleaningState) -> Bool {
        if case .hovering = state { return true }
        return false
    }

    private var stateText: String {
        if case .hovering(let id, _) = state { return "hovering(\(id))" }
        return state == .preparing ? "preparing" : "\(state)"
    }

    private func nextText(_ next: CleaningState) -> String {
        if case .hovering(let id, _) = next { return "hovering(\(id))" }
        return "\(next)"
    }

    private func toMacleanError(_ error: Error) -> MacleanError {
        if let macleanError = error as? MacleanError {
            return macleanError
        }
        return .eventTapCreationFailed(error.localizedDescription)
    }
}
