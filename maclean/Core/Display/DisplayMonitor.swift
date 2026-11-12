import AppKit
import Foundation

/// 显示器热插拔、布局变化与睡眠唤醒监听（开发文档 §10、§4.4）。
@MainActor
final class DisplayMonitor {
    /// 配置变化通知（主线程）：热插拔 / 分辨率 / 排列变化
    var onConfigurationChanged: (() -> Void)?
    /// 显示器唤醒通知（主线程）：唤醒后窗口与 HUD 位置可能漂移，上层应重新校准
    var onScreensWake: (() -> Void)?

    private var configurationObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    func start() {
        guard configurationObserver == nil else { return }
        configurationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onConfigurationChanged?()
        }
        wakeObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onScreensWake?()
        }
        Log.display.notice("显示器变化/唤醒通知已注册")
    }

    /// 注销监听。幂等，可重复调用。
    func stop() {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
        if let wakeObserver {
            NotificationCenter.default.removeObserver(wakeObserver)
        }
        configurationObserver = nil
        wakeObserver = nil
    }
}
