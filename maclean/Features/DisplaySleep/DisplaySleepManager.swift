import AppKit
import Foundation

/// 息屏功能的用户级入口（文档 §2.2 交互）。
///
/// pmset 子进程在后台队列执行（主线程保护惯例——本项目的两次事故都与
/// 主线程被同步系统调用阻塞有关），结果回调主线程。
@MainActor
final class DisplaySleepManager: ObservableObject {
    /// 执行息屏。不锁屏、不整机睡眠、不改系统设置；成功静默，失败回调错误。
    func sleepNow(completion: @escaping (MacleanError?) -> Void) {
        Log.displaySleep.notice("收到息屏请求")
        DispatchQueue.global(qos: .userInitiated).async {
            var failure: MacleanError?
            do {
                try DisplaySleepService.sleepDisplays()
            } catch let macleanError as MacleanError {
                failure = macleanError
            } catch {
                failure = .displaySleepFailed(error.localizedDescription)
            }
            DispatchQueue.main.async {
                completion(failure)
            }
        }
    }
}
