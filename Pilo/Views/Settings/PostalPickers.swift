import SwiftUI

// MARK: - Language Card Picker（两张信纸卡片切换）

/// Picker for Language — 两张并排卡片，选中态有金色描边 + 蜡封图标。
struct LanguageCardPicker: View {
    @Binding var selection: Language
    let onChange: (Language) -> Void

    var body: some View {
        HStack(spacing: PiloSpacing.m) {
            ForEach(Language.allCases, id: \.self) { lang in
                card(for: lang)
                    .onTapGesture {
                        guard selection != lang else { return }
                        selection = lang
                        onChange(lang)
                    }
            }
        }
    }

    private func card(for lang: Language) -> some View {
        let isSelected = selection == lang
        let nativeName = lang.nativeName
        let preview: String = {
            switch lang {
            case .zh: return "「咕咕～」"
            case .en: return "“Coo coo~”"
            }
        }()

        return VStack(spacing: 4) {
            Text(nativeName)
                .font(.piloSerifTitle)
                .tracking(0.5)
                .foregroundStyle(isSelected ? Color.piloBlueDark : Color.inkSecondary)
            Text(preview)
                .font(.piloSerifSubtitle)
                .foregroundStyle(isSelected ? Color.piloGoldDark : Color.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PiloSpacing.l)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.piloPaper : Color.paperCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Color.piloGold : Color.piloPaperBorder,
                        lineWidth: isSelected ? 1.5 : 0.5)
        )
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.piloGold)
                    .padding(8)
            }
        }
        .contentShape(Rectangle())
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Tone Card Picker（两张堆叠卡片预览语气）

struct ToneCardPicker: View {
    @Binding var selection: Tone
    @Environment(AppState.self) private var appState
    let onChange: (Tone) -> Void

    private var lang: Language { appState.language }

    var body: some View {
        VStack(spacing: PiloSpacing.s) {
            ForEach(Tone.allCases, id: \.self) { tone in
                card(for: tone)
                    .onTapGesture {
                        guard selection != tone else { return }
                        selection = tone
                        onChange(tone)
                    }
            }
        }
    }

    private func card(for tone: Tone) -> some View {
        let isSelected = selection == tone
        let title = tone.displayName
        let preview = Copy.menubarPendingHeader(tone, lang, count: 3)

        return HStack(alignment: .center, spacing: PiloSpacing.m) {
            // 单选圆点
            Circle()
                .fill(isSelected ? Color.piloBlue : Color.clear)
                .frame(width: 9, height: 9)
                .overlay(
                    Circle().stroke(isSelected ? Color.piloBlue : Color.inkTertiary, lineWidth: 1.5)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.piloSerifTitle)
                    .tracking(0.3)
                    .foregroundStyle(Color.inkPrimary)
                Text("\u{201C}\(preview)\u{201D}")
                    .font(.piloSerifSubtitle)
                    .foregroundStyle(Color.piloGoldDark)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, PiloSpacing.l)
        .padding(.vertical, PiloSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.piloPaper : Color.paperCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Color.piloBlue.opacity(0.5) : Color.piloPaperBorder,
                        lineWidth: isSelected ? 1.5 : 0.5)
        )
        .contentShape(Rectangle())
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - 信纸添加按钮（虚线金边）

struct PiloAddRowButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.piloGold)
                Text(title)
                    .font(.piloSerifSubtitle)
                    .foregroundStyle(Color.piloGoldDark)
            }
            .padding(.horizontal, PiloSpacing.l)
            .padding(.vertical, PiloSpacing.s)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isHovered ? Color.piloPaper.opacity(0.6) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.piloGold,
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - 优雅的 Remove / Restore 文字按钮

struct PiloLinkButton: View {
    let title: String
    var tint: Color = .piloBlue
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.piloSerifSubtitle)
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovered ? tint.opacity(0.10) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
