import CoreGraphics
import Foundation

/// 全局常量。产品默认值集中在此，1.0 阶段热区位置与悬停时长为固定产品决策（文档 §2.6、§4.9）。
enum AppConstants {
    // 标识
    static let bundleIdentifier = "com.ethon.maclean"
    static let subsystem = "com.ethon.maclean"

    // 退出热区 = 中央 HUD 区域（用户 2026-11-11 决策，覆盖开发文档 §5.1"右上角"）
    /// 默认悬停时长（开发文档 §5.4）；可在设置中调整
    static let defaultHoverDuration: TimeInterval = 1.5
    /// 悬停时长可设置范围与步进
    static let hoverDurationRange = 0.5...5.0
    static let hoverDurationStep = 0.5
    static let hoverDurationKey = "hoverDuration"

    // 中央 HUD（卡片尺寸 = 悬停热区大小；面板另加投影余量）
    static let hudSize = CGSize(width: 360, height: 160)
    static let hudCornerRadius: CGFloat = 20
    /// HUD 面板（窗口）尺寸：卡片四周留投影/光晕余量
    static let hudWindowSize = CGSize(width: 420, height: 220)
    /// 圆环进度
    static let hudRingSize: CGFloat = 68
    static let hudRingWidth: CGFloat = 5

    // 体验打磨（用户 2026-11-11 批准）
    /// 黑屏窗口进入淡入 / 退出淡出时长（键盘恢复始终同步先行，淡出纯视觉）
    static let fadeDuration: TimeInterval = 0.18
    /// 热区滞后带：离开判定比进入判定外扩的边距（防边缘抖动反复清零；
    /// 用户批准的 §5.3 严格重置条款的放宽）
    static let hotspotHysteresis: CGFloat = 6
    /// 进度走满后的高亮反馈时长，随后才真正退出
    static let completedFlashDuration: TimeInterval = 0.12

    // 鼠标轮询（单调时钟计时，见文档 §4.8）
    static let mousePollInterval: TimeInterval = 1.0 / 30.0

    // 视觉（文档 §3.2）
    static let tipBackgroundColorHex = 0x292929
    static let brandAccentColorHex = 0x2563EB
    static let tipOpacity = 0.88
    static let tipCornerRadius: CGFloat = 12
    static let tipAnimationDuration: TimeInterval = 0.15

    // EventTap 安全机制（文档 §4.7、§5.4：tap 可能被系统禁用，必须检测并处理）
    static let maxTapReenableAttempts = 5
    static let tapReenableResetWindow: TimeInterval = 2.0

    // 清洁模式安全兜底（文档 §5.4；快捷键逃生通道已按用户 2026-11-12 决策移除）
    /// 最长清洁时长，超过自动退出
    static let maxCleaningDuration: TimeInterval = 600
    /// 清洁期间节流诊断日志间隔
    static let diagnosticsInterval: TimeInterval = 3.0
    /// tap 创建时主线程的有界等待时长（超时即回滚，绝不阻塞主线程）
    static let tapStartMainThreadWait: TimeInterval = 2.0
    /// 主线程看门狗：清洁期间 ping 间隔、单次超时与连续失联次数上限
    static let watchdogInterval: TimeInterval = 30.0
    static let watchdogPingTimeout: TimeInterval = 3.0
    static let watchdogMaxMisses = 2

    // 息屏实现（文档 §4.5 PoC 结论候选：pmset displaysleepnow）
    static let pmsetPath = "/usr/bin/pmset"

    // UserDefaults 键
    static let launchAtLoginKey = "launchAtLogin"
}
