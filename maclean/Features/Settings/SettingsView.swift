import SwiftUI

/// 设置窗口（文档 §2.6：只提供必要设置，不为功能丰富而过早暴露选项）。
struct SettingsView: View {
    @ObservedObject private var settings = AppEnvironment.shared.settings

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("通用", systemImage: "gearshape")
                }
            cleaningTab
                .tabItem {
                    Label("清洁", systemImage: "sparkles")
                }
            aboutTab
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .frame(width: 440, height: 240)
    }

    // MARK: - 通用

    private var generalTab: some View {
        Form {
            Toggle("开机自启（登录时启动 Maclean）", isOn: $settings.launchAtLogin)

            if let error = settings.loginItemError {
                Text("登录启动设置失败：\(error)")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Text("清洁模式涉及全局键盘过滤，Maclean 不记录键盘内容和鼠标轨迹。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    // MARK: - 清洁

    private var cleaningTab: some View {
        Form {
            VStack(alignment: .leading, spacing: 6) {
                Text("退出悬停时长：\(HoverTipFormatter.secondsText(settings.effectiveHoverDuration)) 秒")
                Slider(
                    value: $settings.hoverDuration,
                    in: AppConstants.hoverDurationRange,
                    step: AppConstants.hoverDurationStep
                )
                Text("把鼠标悬停到屏幕中央的提示框上，持续此时长后退出清洁模式（0.5 – 5 秒）")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            LabeledContent("退出热区位置", value: "屏幕中央提示框（固定）")
            LabeledContent("多显示器", value: "全部支持（固定）")
            LabeledContent("键盘", value: "清洁期间全部屏蔽（无例外）")
        }
        .padding(20)
    }

    // MARK: - 关于

    private var aboutTab: some View {
        Form {
            LabeledContent("版本", value: Self.versionText)
            LabeledContent("隐私", value: "不记录键盘内容、不上传任何数据、无账号、无云端")
            LabeledContent("开源协议", value: "MIT · 免费使用")
        }
        .padding(20)
    }

    private static var versionText: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }
}
