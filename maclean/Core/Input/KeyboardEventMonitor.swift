import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// 全局输入过滤与监听服务（文档 §4.7）。
///
/// 架构：
/// - tap 挂载在 **HID 硬件层**（kCGHIDEventTap，2026-11-12 修正）：在窗口服务器分发
///   与系统快捷键处理之前拦截事件。此前挂在 session 层，擦键盘的事件洪流冲垮 tap
///   以及系统保留快捷键路径的泄漏，导致清洁中触发锁屏。HID 层 = 真正的"死键盘"
///   （与 KeyboardCleanTool 等键盘清洁工具同款机制）。
/// - 掩码额外包含 NX_SYSDEFINED（raw 14）：功能键行的亮度/音量/媒体键以系统定义
///   事件形式经 HID 层派发，一并吞掉（2026-11-12 漏键修复）。
/// - tap 在**专用线程**上创建并运行（Apple 推荐模式），start() 只让主线程
///   **有界等待**（默认 2 秒）；超时即回调失败、主线程立即回滚，绝不卡死界面。
/// - tap 生命周期回调（鼠标移动、失效通知）从 tap 线程转发到主线程执行。
///
/// 安全机制（文档 §5.4）：
/// - 创建前检查辅助功能授权，未授权回调失败，绝不让用户误以为键盘已被屏蔽；
/// - tap 被系统禁用时自动重启用，持续失效通知上层安全退出；
/// - 无快捷键逃生通道（用户 2026-11-12 决策）：键盘事件一律吞掉。
/// - 硬件按键（Touch ID/电源键锁屏）不经事件系统，无法屏蔽——能力边界如实告知。
final class KeyboardEventMonitor {
    enum StartOutcome {
        case success
        case failure(MacleanError)
    }

    /// 鼠标移动回调（主线程）。坐标为 CG 全局坐标（主屏左上原点，y 向下）。
    var onMouseMoved: ((CGPoint, DispatchTime) -> Void)?
    /// tap 持续失效回调（主线程，上层应安全退出清洁模式）
    var onBroken: (() -> Void)?

    private let stateLock = NSLock()
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapRunLoop: CFRunLoop?
    private var stopRequested = false
    /// 主线程等待超时后置位，tap 线程据此放弃残留 tap 并自毁
    private var abandonedByCaller = false
    private var activeFlag = false

    /// tap 是否处于启用状态（线程安全）
    var isActive: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return activeFlag
    }

    // tap 线程专用（无需加锁）
    private var disableCount = 0
    private var lastDisableAt: DispatchTime?
    private var lastForwardAt: DispatchTime = DispatchTime(uptimeNanoseconds: 0)

    // MARK: - 辅助功能权限

    /// 检查辅助功能授权（线程安全）。`prompt` 为 true 时弹系统授权引导。
    static func isAccessibilityGranted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    /// 系统设置中辅助功能面板的打开地址
    static let accessibilitySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )!

    // MARK: - 启动（主线程调用，有界等待）

    /// 在专用线程创建 tap。主线程最多阻塞 `mainWaitTimeout` 秒，之后无论结果都回调并返回。
    /// completion 保证在主线程、且只回调一次。可反复调用（进入/退出清洁模式循环）。
    func start(mainWaitTimeout: TimeInterval = AppConstants.tapStartMainThreadWait,
               completion: @escaping (StartOutcome) -> Void) {
        assert(Thread.isMainThread, "start() 必须在主线程调用")

        stateLock.lock()
        // 上一次会话的停止标志必须复位，否则第二次进入永远失败（2026-11-11 用户实测 bug）
        stopRequested = false
        abandonedByCaller = false
        if activeFlag {
            stateLock.unlock()
            completion(.success)
            return
        }
        stateLock.unlock()

        let semaphore = DispatchSemaphore(value: 0)
        let lifecycleLock = NSLock()
        var threadOutcome: StartOutcome?
        var completed = false

        func finishOnMain(_ outcome: StartOutcome) {
            lifecycleLock.lock()
            guard !completed else {
                lifecycleLock.unlock()
                return
            }
            completed = true
            lifecycleLock.unlock()
            DispatchQueue.main.async {
                completion(outcome)
            }
        }

        let thread = Thread { [weak self] in
            guard let self else { return }
            let result = self.createTapOnCurrentThread()
            // 本线程持有自己的 tap 上下文；清理时只用本地引用，
            // 避免旧线程清理误伤新会话的共享状态（若快速退出重进）
            let myTap = result.tap
            let mySource = result.source
            let myRunLoop = result.runLoop

            lifecycleLock.lock()
            self.stateLock.lock()
            let abandoned = self.abandonedByCaller || self.stopRequested
            self.stateLock.unlock()
            threadOutcome = result.outcome
            lifecycleLock.unlock()

            semaphore.signal()

            if case .failure(let outcomeError) = result.outcome {
                self.cleanupTap(tap: myTap, source: mySource, runLoop: myRunLoop)
                finishOnMain(.failure(outcomeError))
                return
            }
            if abandoned {
                // 主线程已超时回滚：回收 tap，不再进入运行循环
                Log.input.notice("主线程已放弃等待，回收刚创建的 tap")
                self.cleanupTap(tap: myTap, source: mySource, runLoop: myRunLoop)
                return
            }
            // 再次确认期间没有被 stop（stop 会 CFRunLoopStop，runloop 立即返回）
            self.stateLock.lock()
            let stopped = self.stopRequested
            self.stateLock.unlock()
            if stopped {
                self.cleanupTap(tap: myTap, source: mySource, runLoop: myRunLoop)
                return
            }
            finishOnMain(result.outcome)
            self.tapThreadRunLoop(tap: myTap, source: mySource, runLoop: myRunLoop)
        }
        thread.name = "com.ethon.maclean.eventtap"
        thread.qualityOfService = .userInitiated
        thread.start()

        let waitResult = semaphore.wait(timeout: .now() + mainWaitTimeout)
        if waitResult == .success {
            lifecycleLock.lock()
            let outcome = threadOutcome ?? .failure(.eventTapCreationFailed("未知结果"))
            lifecycleLock.unlock()
            finishOnMain(outcome)
        } else {
            stateLock.lock()
            abandonedByCaller = true
            stateLock.unlock()
            Log.input.error("tap 创建超过 \(Int(mainWaitTimeout)) 秒未完成，主线程放弃等待并回滚")
            finishOnMain(.failure(.eventTapCreationFailed("tap 创建超时（\(Int(mainWaitTimeout)) 秒）")))
        }
    }

    // MARK: - tap 线程

    /// 在当前（专用）线程创建并启用 tap。返回结果与线程私有的 tap 上下文。
    private func createTapOnCurrentThread() -> (outcome: StartOutcome, tap: CFMachPort?, source: CFRunLoopSource?, runLoop: CFRunLoop?) {
        stateLock.lock()
        if stopRequested {
            stateLock.unlock()
            return (.failure(.eventTapCreationFailed("已请求停止")), nil, nil, nil)
        }
        stateLock.unlock()

        guard Self.isAccessibilityGranted(prompt: false) else {
            return (.failure(.accessibilityPermissionNeeded), nil, nil, nil)
        }

        let keyMask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue)
                | (1 << CGEventType.keyUp.rawValue)
                | (1 << CGEventType.flagsChanged.rawValue)
        )
        let mouseMask = CGEventMask(
            (1 << CGEventType.mouseMoved.rawValue)
                | (1 << CGEventType.leftMouseDragged.rawValue)
                | (1 << CGEventType.rightMouseDragged.rawValue)
                | (1 << CGEventType.otherMouseDragged.rawValue)
        )
        // NX_SYSDEFINED（raw 14）：功能键行的系统功能键（亮度/音量/媒体）以此形式
        // 经 HID 层派发。不加入掩码的话这些键会绕过 tap 直接被系统消费（2026-11-12 漏键修复）
        let sysDefinedMask = CGEventMask(1 << 14)

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: keyMask | mouseMask | sysDefinedMask,
            callback: Self.callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return (.failure(.eventTapCreationFailed("CGEventTapCreate 返回 nil")), nil, nil, nil)
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        let runLoop = CFRunLoopGetCurrent()
        CFRunLoopAddSource(runLoop, source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        stateLock.lock()
        self.tap = tap
        self.runLoopSource = source
        self.tapRunLoop = runLoop
        self.activeFlag = true
        stateLock.unlock()

        Log.input.notice("输入过滤 tap 已创建并启用（HID 硬件层 · 专用线程）")
        return (.success, tap, source, runLoop)
    }

    /// tap 线程的常驻运行循环，直到 stop() 触发 CFRunLoopStop。
    private func tapThreadRunLoop(tap: CFMachPort?, source: CFRunLoopSource?, runLoop: CFRunLoop?) {
        CFRunLoopRun()
        cleanupTap(tap: tap, source: source, runLoop: runLoop)
    }

    /// 释放 tap（在拥有它的 tap 线程调用，只使用传入的本线程上下文）。
    /// 顺序按开发文档 §7.3：先禁用 tap，再移除 RunLoop source，最后释放引用。
    /// 共享状态仅在仍指向本线程上下文时才清除——防止快速退出重进时
    /// 旧线程的清理误伤新会话的 tap。
    private func cleanupTap(tap: CFMachPort?, source: CFRunLoopSource?, runLoop: CFRunLoop?) {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source, let runLoop {
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
        }
        if let tap {
            CFMachPortInvalidate(tap)
        }
        stateLock.lock()
        if self.tapRunLoop === runLoop {
            self.tap = nil
            self.runLoopSource = nil
            self.tapRunLoop = nil
            self.activeFlag = false
        }
        stateLock.unlock()
        Log.input.notice("输入过滤 tap 已释放")
    }

    // MARK: - 停止（任意线程，幂等）

    func stop() {
        stateLock.lock()
        stopRequested = true
        let runLoop = tapRunLoop
        stateLock.unlock()
        // CFRunLoopStop 可跨线程调用；对尚未运行/已停止的 runloop 也安全
        if let runLoop {
            CFRunLoopStop(runLoop)
        }
    }

    // MARK: - 事件回调（tap 线程）

    /// 键盘事件一律吞掉（不读取任何字符内容，无任何快捷键逃生通道）；
    /// 鼠标移动事件读取位置后原样放行。
    private static let callback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let monitor = Unmanaged<KeyboardEventMonitor>.fromOpaque(refcon).takeUnretainedValue()

        switch type {
        case .keyDown, .keyUp, .flagsChanged:
            return nil

        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // tap 状态通知，不是键盘事件：轻量通知后事件放行（开发文档 §7.2）
            monitor.handleTapDisabled()
            return Unmanaged.passUnretained(event)

        default:
            // NX_SYSDEFINED（type 14）：功能键行的系统功能键（亮度/音量/媒体）。
            // 吞掉 = 功能键行死键（用户 2026-11-12 要求全屏蔽），事件本身放行与否无关紧要
            if type.rawValue == 14 {
                return nil
            }
            // mouseMoved / *_mouseDragged：节流后转发主线程，事件本身放行
            // mouseMoved / *_mouseDragged：节流后转发主线程，事件本身放行
            let now = DispatchTime.now()
            let elapsed = now.uptimeNanoseconds > monitor.lastForwardAt.uptimeNanoseconds
                ? now.uptimeNanoseconds - monitor.lastForwardAt.uptimeNanoseconds
                : 0
            if elapsed > 8_000_000 {  // ≤125Hz，足够热区检测
                monitor.lastForwardAt = now
                let location = event.location
                DispatchQueue.main.async {
                    monitor.onMouseMoved?(location, now)
                }
            }
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleTapDisabled() {
        guard let tap else { return }
        let now = DispatchTime.now()
        // 距上次禁用超过重置窗口则视为偶发超时，重新计数
        if let lastDisableAt, now.uptimeNanoseconds - lastDisableAt.uptimeNanoseconds
            < UInt64(AppConstants.tapReenableResetWindow * 1_000_000_000) {
            disableCount += 1
        } else {
            disableCount = 1
        }
        lastDisableAt = now

        Log.input.warning("EventTap 被系统禁用，尝试重新启用（第 \(self.disableCount) 次）")
        CGEvent.tapEnable(tap: tap, enable: true)

        if disableCount >= AppConstants.maxTapReenableAttempts {
            Log.input.error("EventTap 持续失效，通知上层安全退出清洁模式")
            DispatchQueue.main.async { [weak self] in
                self?.onBroken?()
            }
        }
    }
}
