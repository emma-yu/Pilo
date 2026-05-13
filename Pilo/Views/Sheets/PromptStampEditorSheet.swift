import SwiftUI

/// 邮票 editor —— 新建或编辑一张 prompt 邮票。
///
/// 视觉：cream paper 信纸 + Songti 标题 + 7 张 illustration 邮票 picker（2 行 × 4 列）+ TextEditor
///
/// **设计简化**：v2 用 7 张 illustration preset 替代 emoji + tint 双 picker —— 决策从
/// 48 组合（8×6）降到 7，视觉立即统一。老 stamps（无 design 字段）编辑时若用户没换 design，
/// 仍保留 emoji+tint fallback；选了任意 design 即覆盖。
struct PromptStampEditorSheet: View {

    /// 初始 stamp —— 新建时传一个空 stamp（title=""），编辑时传现有 stamp
    let initial: PromptStamp

    @Environment(AppState.self) private var appState
    private var lang: Language { appState.language }

    @State private var title: String
    @State private var body_: String
    @State private var design: StampDesign?
    @State private var pinned: Bool

    init(initial: PromptStamp) {
        self.initial = initial
        _title = State(initialValue: initial.title)
        _body_ = State(initialValue: initial.body)
        _design = State(initialValue: initial.design ?? .checklist)  // 默认第一张
        _pinned = State(initialValue: initial.pinned)
    }

    private var isNew: Bool { initial.title.isEmpty && initial.body.isEmpty }
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !body_.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Rectangle()
                .fill(Color.piloGold.opacity(0.4))
                .frame(height: 0.5)
            ScrollView {
                content
                    .padding(.horizontal, 36)
                    .padding(.vertical, 22)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            footer
        }
        .frame(width: 560, height: 660)
        .background(Color.piloPaper.opacity(0.95))
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: isNew ? "plus.circle.fill" : "pencil.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.piloGoldDark)
            Text(isNew ? Copy.Stamps.editorNewTitle(lang) : Copy.Stamps.editorEditTitle(lang))
                .font(.piloSerifTitle)
                .foregroundStyle(Color.inkPrimary)
            Spacer()
            Button(action: { appState.closeStampEditor() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.inkSecondary)
                    .padding(6)
                    .background(Circle().fill(Color.cloudDivider.opacity(0.4)))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标签
            VStack(alignment: .leading, spacing: 6) {
                sectionLabel(Copy.Stamps.fieldTitle(lang))
                TextField(Copy.Stamps.fieldTitlePlaceholder(lang), text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.inkPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.piloPaper.opacity(0.6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.piloGold.opacity(0.35), lineWidth: 0.5)
                    )
            }

            // 邮票 illustration picker —— 替代 emoji + tint
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel(Copy.Stamps.fieldDesign(lang))
                designPickerGrid
            }

            // Prompt 内容
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    sectionLabel(Copy.Stamps.fieldBody(lang))
                    Spacer()
                    // 「用模板」inline 按钮 —— 仅 body 为空 + 已选 design 时显示，
                    // 帮新用户跨过"白纸恐惧"
                    if body_.isEmpty, let d = design {
                        Button(action: { body_ = d.templateBody(lang) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 10, weight: .medium))
                                Text(Copy.Stamps.useTemplate(lang))
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(Color.piloGoldDark)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.piloGold.opacity(0.12)))
                            .overlay(Capsule().stroke(Color.piloGold.opacity(0.4), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .help(Copy.Stamps.useTemplateHint(lang))
                    }
                }
                ZStack(alignment: .topLeading) {
                    if body_.isEmpty {
                        Text(Copy.Stamps.fieldBodyPlaceholder(lang))
                            .font(.system(size: 13))
                            .foregroundStyle(Color.inkTertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                    }
                    TextEditor(text: $body_)
                        .font(.system(size: 13))
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }
                .frame(minHeight: 120)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.piloPaper.opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.piloGold.opacity(0.35), lineWidth: 0.5)
                )
            }

            // 钉住 checkbox
            Toggle(isOn: $pinned) {
                Text(Copy.Stamps.fieldPin(lang))
                    .font(.piloSerifSubtitle)
                    .foregroundStyle(Color.inkPrimary)
            }
            .toggleStyle(.checkbox)
            .tint(Color.piloGoldDark)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.piloSerifLabel)
            .tracking(1.0)
            .foregroundStyle(Color.piloGoldDark)
    }

    // MARK: - Design picker grid（4 列 × 2 行 = 8 格，7 个 illustration + 1 空）

    private var designPickerGrid: some View {
        let cols: [GridItem] = Array(
            repeating: GridItem(.flexible(), spacing: 12, alignment: .center),
            count: 4
        )
        return LazyVGrid(columns: cols, alignment: .center, spacing: 14) {
            ForEach(StampDesign.allCases, id: \.self) { d in
                designCell(d)
            }
        }
    }

    private func designCell(_ d: StampDesign) -> some View {
        let isSelected = design == d
        return Button(action: { design = d }) {
            VStack(spacing: 5) {
                Image(d.imageName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 64, height: 60)
                    .rotationEffect(.degrees(isSelected ? 0 : -3))
                    .scaleEffect(isSelected ? 1.06 : 1.0)
                Text(lang == .zh ? d.labelZH : d.labelEN)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? Color.piloGoldDark : Color.inkSecondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.piloGold.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isSelected ? Color.piloGoldDark.opacity(0.55) : Color.clear,
                        lineWidth: 0.8
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button(Copy.Stamps.cancelAction(lang)) {
                appState.closeStampEditor()
            }
            .buttonStyle(.piloSecondary)

            Button(Copy.Stamps.saveAction(lang)) {
                save()
            }
            .buttonStyle(.piloPrimary)
            .disabled(!canSave)
            .keyboardShortcut(.return, modifiers: [.command])
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color.piloPaper.opacity(0.4))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.piloGold.opacity(0.3))
                        .frame(height: 0.5)
                }
        )
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body_.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedBody.isEmpty else { return }

        if isNew {
            let stamp = PromptStamp(
                title: trimmedTitle,
                body: trimmedBody,
                pinned: pinned,
                design: design
            )
            appState.addPromptStamp(stamp)
        } else {
            var updated = initial
            updated.title = trimmedTitle
            updated.body = trimmedBody
            updated.pinned = pinned
            updated.design = design  // 覆盖旧 emoji+tint
            appState.updatePromptStamp(updated)
        }
        appState.closeStampEditor()
    }
}
