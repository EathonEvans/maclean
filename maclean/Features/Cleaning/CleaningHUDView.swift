import SwiftUI

/// 屏幕中央 HUD（玻璃卡片 + 圆环进度，2026-11-12 重构样式）。
///
/// 构图：圆环环绕光标图标（进度 0→100% 旋转填充），下方提示文案。
/// 反馈：悬停时圆环微放大、描边增亮；完成时图标变对勾、圆环满格，
/// 随后随整体淡出退出。进度是否平滑由动画决定，退出只看真实 elapsed（§6.4）。
struct CleaningHUDView: View {
    @ObservedObject var model: CleaningHUDModel

    var body: some View {
        VStack(spacing: 12) {
            ring
            Text(model.text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.92))
            // 键盘屏蔽状态明示（用户 2026-11-12 要求）
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .semibold))
                Text("已禁用键盘")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(Color.white.opacity(0.45))
        }
        .frame(width: AppConstants.hudSize.width, height: AppConstants.hudSize.height)
        .background(
            RoundedRectangle(cornerRadius: AppConstants.hudCornerRadius)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.hudCornerRadius)
                .strokeBorder(
                    Color.white.opacity(model.isHovered || model.isCompleted ? 0.35 : 0.16),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 16, y: 5)
        .animation(.easeInOut(duration: 0.15), value: model.isHovered)
        .animation(.easeInOut(duration: 0.12), value: model.isCompleted)
    }

    /// 圆环：底轨 + 进度弧 + 中心图标。悬停微放大。
    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: AppConstants.hudRingWidth)
            Circle()
                .trim(from: 0, to: model.progress)
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: AppConstants.hudRingWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: AppConstants.mousePollInterval), value: model.progress)
            Image(systemName: model.isCompleted ? "checkmark" : "cursorarrow.motionlines")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.white.opacity(model.isCompleted ? 1 : 0.95))
        }
        .frame(width: AppConstants.hudRingSize, height: AppConstants.hudRingSize)
        .background(Circle().fill(Color.white.opacity(model.isHovered ? 0.08 : 0.04)))
        .scaleEffect(model.isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: model.isHovered)
    }
}

extension Color {
    /// 从 0xRRGGBB 构建颜色
    init(hex: Int) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255
        )
    }
}

/// HUD 显示状态模型
@MainActor
final class CleaningHUDModel: ObservableObject {
    /// 提示文案
    @Published var text: String
    /// 悬停进度 0…1
    @Published var progress: Double = 0
    /// 鼠标是否正悬停在此 HUD 上（圆环放大、描边增亮）
    @Published var isHovered = false
    /// 计时已完成（对勾 + 圆环满格，随后随整体淡出）
    @Published var isCompleted = false

    init(text: String) {
        self.text = text
    }

    func resetProgress() {
        progress = 0
        isCompleted = false
    }
}
