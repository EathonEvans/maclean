import AppKit
import Foundation

/// 应用级对象容器。规模很小，直接共享容器，不引入依赖注入框架（文档 §4.3）。
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let settings: SettingsManager
    let settingsWindow = SettingsWindowController()
    let displaySleep: DisplaySleepManager
    let cleaning: CleaningManager

    private init() {
        let settings = SettingsManager()
        self.settings = settings
        self.displaySleep = DisplaySleepManager()
        self.cleaning = CleaningManager(settings: settings)
    }
}
