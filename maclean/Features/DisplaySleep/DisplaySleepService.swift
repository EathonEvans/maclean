import Foundation

/// 息屏底层实现：调用 `pmset displaysleepnow`（文档 §4.5 PoC 首选路径）。
///
/// 关键约束（文档 §2.2、§4.5）：
/// - 这是 Display Sleep，不是系统睡眠，更不是锁屏；
/// - 不持有任何阻止显示器休眠的电源断言，不修改系统睡眠设置；
/// - 自用版未启用沙盒，`Process` 调用无需额外授权（正式分发场景需另行 PoC）。
enum DisplaySleepService {
    static let executablePath = AppConstants.pmsetPath

    /// 同步执行显示器休眠。成功时显示器随即关闭；失败抛出错误供上层反馈。
    static func sleepDisplays() throws {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["displaysleepnow"]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            throw MacleanError.displaySleepFailed("无法启动 \(executablePath)：\(error.localizedDescription)")
        }

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = String(data: outputData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let suffix = message.isEmpty ? "" : "：\(message)"
            throw MacleanError.displaySleepFailed("退出码 \(process.terminationStatus)\(suffix)")
        }
        Log.displaySleep.info("显示器休眠指令执行成功")
    }
}
