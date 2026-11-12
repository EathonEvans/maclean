import AppKit
import Foundation
import ServiceManagement

/// 本地配置读写（文档 §4.9）。
///
/// 可配置项：
/// - 登录时启动（文档 §9.3）
/// - 清洁模式退出悬停时长（用户 2026-11-11 决策，覆盖文档"固定 1.5 秒"）
///
/// 固定项（保留配置字段便于后续扩展）：
/// - 退出热区位置：每块显示器右上角
/// - 多显示器：全部支持
@MainActor
final class SettingsManager: ObservableObject {
    /// 登录启动。默认由用户主动开启。
    @Published var launchAtLogin: Bool {
        didSet {
            guard oldValue != launchAtLogin else { return }
            applyLaunchAtLogin()
        }
    }

    /// 清洁模式退出悬停时长（秒）。UI 滑块已限定范围，读取侧再做一次钳制兜底。
    /// 滑块拖动会产生连续变更，落盘做 0.4s 防抖，避免一次拖动写盘几十次。
    @Published var hoverDuration: Double {
        didSet {
            guard oldValue != hoverDuration else { return }
            schedulePersistHoverDuration()
        }
    }

    // 固定产品默认值（保留配置模型）
    let hotspotPosition = "topRight"
    let multiDisplayEnabled = true

    /// 最近一次登录启动设置失败的提示（供设置界面展示）
    @Published private(set) var loginItemError: String?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // 以系统真实状态为准，避免「已申请」被误认为「已生效」（文档 §6.1）
        self.launchAtLogin = (SMAppService.mainApp.status == .enabled)

        let stored = defaults.double(forKey: AppConstants.hoverDurationKey)
        let range = AppConstants.hoverDurationRange
        self.hoverDuration = range.contains(stored) ? stored : AppConstants.defaultHoverDuration
    }

    /// 实际生效的悬停时长（钳制在允许范围内）
    var effectiveHoverDuration: Double {
        min(max(hoverDuration, AppConstants.hoverDurationRange.lowerBound),
            AppConstants.hoverDurationRange.upperBound)
    }

    /// 系统设置中的真实登录项状态
    var systemLoginItemStatusIsEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    // MARK: - 悬停时长落盘（防抖）

    private var persistWork: DispatchWorkItem?

    private func schedulePersistHoverDuration() {
        persistWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            defaults.set(self.hoverDuration, forKey: AppConstants.hoverDurationKey)
            Log.settings.notice("悬停时长已保存：\(self.hoverDuration) 秒")
        }
        persistWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            defaults.set(launchAtLogin, forKey: AppConstants.launchAtLoginKey)
            loginItemError = nil
            Log.settings.notice("登录启动设置成功：\(self.launchAtLogin)")
        } catch {
            // 注册失败：展示明确反馈并回读系统真实状态（文档 §9.3）
            loginItemError = error.localizedDescription
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
            Log.settings.error("登录启动设置失败：\(error.localizedDescription, privacy: .public)")
        }
    }
}
