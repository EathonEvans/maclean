import SwiftUI

/// 菜单栏下拉面板（SwiftUI 定制卡片，替代原生 NSMenu 的纯文字列表）。
///
/// 结构：品牌页头 → 核心动作（显示器休眠/清洁模式）→ 次级动作（设置/关于）→ 退出。
/// 视觉：图标色块 + 悬停高亮 + 分组分隔，随系统深浅色自适应。
/// 文案按用户 2026-11-12 要求：息屏→显示器休眠、清洁→清洁模式，无副标题、无版本号。
struct MenuBarPanelView: View {
    var onSleep: () -> Void
    var onClean: () -> Void
    var onSettings: () -> Void
    var onAbout: () -> Void
    var onQuit: () -> Void

    @State private var hoveredTag: String?
    private let accent = Color(hex: AppConstants.brandAccentColorHex)

    var body: some View {
        VStack(spacing: 2) {
            header
            divider
            MenuRow(tag: "sleep", icon: "display", title: "显示器休眠",
                    tint: accent, hoveredTag: hoveredTag, action: onSleep)
            MenuRow(tag: "clean", icon: "sparkles", title: "清洁模式",
                    tint: accent, hoveredTag: hoveredTag, action: onClean)
            divider
            MenuRow(tag: "settings", icon: "gearshape", title: "设置...",
                    tint: .secondaryIconTint, hoveredTag: hoveredTag, action: onSettings)
            MenuRow(tag: "about", icon: "info.circle", title: "关于 maclean",
                    tint: .secondaryIconTint, hoveredTag: hoveredTag, action: onAbout)
            divider
            MenuRow(tag: "quit", icon: "power", title: "退出 maclean",
                    tint: .quitIconTint, hoveredTag: hoveredTag, action: onQuit)
        }
        .frame(width: 252)
        .padding(.vertical, 6)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image("MenuBarTemplate")
                .resizable()
                .renderingMode(.template)
                .frame(width: 18, height: 18)
                .foregroundStyle(accent)
            Text("Maclean")
                .font(.system(size: 14, weight: .semibold))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var divider: some View {
        Divider().padding(.horizontal, 10).padding(.vertical, 3)
    }
}

/// 单行菜单项：图标色块 + 标题，悬停整行高亮。
private struct MenuRow: View {
    let tag: String
    let icon: String
    let title: String
    let tint: Color
    let hoveredTag: String?
    let action: () -> Void

    @State private var nativeHover = false

    private var isHovered: Bool { hoveredTag == tag || nativeHover }

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(tint.opacity(0.14))
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(tint)
                }
                .frame(width: 26, height: 26)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(isHovered ? 0.08 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            nativeHover = hovering
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

extension Color {
    /// 次级动作（设置/关于）的中性色块
    static var secondaryIconTint: Color {
        Color.primary.opacity(0.55)
    }

    /// 退出的警示色块
    static var quitIconTint: Color {
        Color.red
    }
}
