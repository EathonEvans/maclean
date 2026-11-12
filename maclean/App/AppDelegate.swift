import AppKit
import Combine
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var didEnterCleaningForSelfTest = false
    private var stateSink: Any?
    private let menuController = MenuBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuController.install()

        let arguments = ProcessInfo.processInfo.arguments
        let isSelfTest = arguments.contains("-macleanCleaningSelfTest")

        // 自检模式：失败只记日志（无人值守，弹窗会挂起进程）
        if isSelfTest {
            AppEnvironment.shared.cleaning.errorHandler = { error in
                Log.app.error("自检失败：\(error.title) — \(error.message, privacy: .public)")
            }
        } else {
            AppEnvironment.shared.cleaning.errorHandler = { error in
                AlertPresenter.show(error)
            }
        }
        Log.app.notice("Maclean 已启动（bundleID: \(AppConstants.bundleIdentifier, privacy: .public)）")
        startSelfTestIfNeeded()
    }

    /// 正常退出前释放所有事件监听与窗口（开发文档 §9：applicationWillTerminate）
    func applicationWillTerminate(_ notification: Notification) {
        AppEnvironment.shared.cleaning.shutdownForTermination()
        Log.app.notice("maclean 即将退出，资源已释放")
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    // MARK: - 自检模式（仅 -macleanCleaningSelfTest 启动参数触发，正常运行无影响）
    //
    // -macleanCleaningSelfTest          2 秒后自动进入清洁模式；进入并退出后记录成功日志并退出进程
    // -macleanSelfTestHover             在自检基础上注入"右上角合成悬停 2.2 秒"，
    //                                   验证 热区→HUD→1.5 秒计时→自动退出 全管线

    private func startSelfTestIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-macleanCleaningSelfTest") else { return }
        let withHover = arguments.contains("-macleanSelfTestHover")

        Log.app.notice("自检模式启动：2 秒后自动进入清洁模式\(withHover ? "，并注入合成悬停" : "")")

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            AppEnvironment.shared.cleaning.enter()
            if withHover {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    Self.runSyntheticHover()
                }
            }
        }

        stateSink = AppEnvironment.shared.cleaning.$state.sink { state in
            if case .cleaning = state {
                Self.didEnterCleaningForSelfTest = true
            }
            if state == .idle && Self.didEnterCleaningForSelfTest {
                Log.app.notice("自检通过：清洁模式完成 进入→运行→退出 全流程")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    Darwin.exit(0)
                }
            }
        }

        // 失败超时：6 秒内未进入 cleaning（如权限缺失、tap 超时）则记录并以非零码退出
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            if !Self.didEnterCleaningForSelfTest {
                Log.app.error("自检失败：6 秒内未进入清洁模式（原因见上方日志）")
                Darwin.exit(1)
            }
        }
    }

    /// 以 30Hz 注入主屏中央（HUD 热区）合成采样点，持续 2.2 秒（> 1.5 秒悬停时长）。
    private static func runSyntheticHover() {
        guard let mainScreen = NSScreen.screens.first else {
            Log.app.error("自检失败：找不到主屏")
            return
        }
        let hudPoint = CGPoint(x: mainScreen.frame.midX, y: mainScreen.frame.midY)
        Log.app.notice("自检：注入合成悬停点 (\(hudPoint.x), \(hudPoint.y))（屏幕中央 HUD 区域），持续 2.2 秒")

        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { t in
            AppEnvironment.shared.cleaning.debugInjectSample(at: hudPoint)
        }
        RunLoop.main.add(timer, forMode: .common)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            timer.invalidate()
            Log.app.notice("自检：合成悬停结束（管线正常时应已在 1.5 秒处自动退出）")
        }
    }
}
