import SwiftUI

/// 信件末尾署名 colophon——金色微型邮戳印记 + 短金线 + Songti SC 10pt italic 工作室署名。
///
/// 视觉创新：左侧 11pt 圆形邮戳（双圈 + 中心点，-8° 微旋）让这行不像应用 footer，
/// 而像真信纸末尾的"承印人印记"。
///
/// 用法：
///   - 不可点（默认）：`ColophonAttribution()` —— 装饰，不要求交互
///   - 可点（step 3 接通）：`ColophonAttribution { appState.openAboutSettings() }`
struct ColophonAttribution: View {
    var onTap: (() -> Void)? = nil

    @Environment(AppState.self) private var appState

    var body: some View {
        if let onTap {
            Button(action: onTap) { row }
                .buttonStyle(.plain)
                .accessibilityLabel(Copy.Studio.letterColophon(appState.language))
                .accessibilityAddTraits(.isLink)
        } else {
            row
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Copy.Studio.letterColophon(appState.language))
        }
    }

    private var row: some View {
        HStack(spacing: 6) {
            MicroPostmark(size: 11)
            Rectangle()
                .fill(Color.piloGold.opacity(0.32))
                .frame(width: 36, height: 0.5)
            Text(Copy.Studio.letterColophon(appState.language))
                .font(.custom("Songti SC", size: 10).italic())
                .foregroundStyle(Color.inkSecondary.opacity(0.65))
                .tracking(0.4)
        }
    }
}

/// 微型圆形邮戳——双层细圈 + 中央实心点，整体 -8° 微旋。
/// 私有给 ColophonAttribution 用；如果未来其它 view 也需要，可提到 DesignSystem。
private struct MicroPostmark: View {
    var size: CGFloat = 11

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.piloGoldDark.opacity(0.55), lineWidth: 0.6)
            Circle()
                .stroke(Color.piloGoldDark.opacity(0.32), lineWidth: 0.4)
                .scaleEffect(0.62)
            Circle()
                .fill(Color.piloGoldDark.opacity(0.55))
                .frame(width: 1.4, height: 1.4)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(-8))
        .accessibilityHidden(true)
    }
}

#Preview("Colophon") {
    VStack(alignment: .leading, spacing: 24) {
        Text("Pilo")
            .font(.custom("Songti SC", size: 22).italic())
            .foregroundStyle(Color.piloGoldDark)
        ColophonAttribution()
        Divider()
        ColophonAttribution { print("tap") }
    }
    .padding(40)
    .background(Color.piloPaper)
}
