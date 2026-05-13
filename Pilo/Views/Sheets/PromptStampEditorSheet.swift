import SwiftUI

/// 邮票 editor —— 新建或编辑一张 prompt 邮票。
///
/// 视觉：cream paper 信纸 + Songti 标题 + OrnamentDivider + emoji picker + tint picker + TextEditor
struct PromptStampEditorSheet: View {

    /// 初始 stamp —— 新建时传一个空 stamp（title=""），编辑时传现有 stamp
    let initial: PromptStamp

    @Environment(AppState.self) private var appState
    private var lang: Language { appState.language }

    @State private var title: String
    @State private var body_: String
    @State private var emoji: String
    @State private var tint: PromptStamp.StampTint
    @State private var pinned: Bool

    private static let emojiPresets: [String] = ["🔧", "📖", "🐛", "✨", "📝", "💡", "🚀", "🧪"]

    init(initial: PromptStamp) {
        self.initial = initial
        _title = State(initialValue: initial.title)
        _body_ = State(initialValue: initial.body)
        _emoji = State(initialValue: initial.emoji.isEmpty ? "✨" : initial.emoji)
        _tint = State(initialValue: initial.tint)
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
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            footer
        }
        .frame(width: 540, height: 620)
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
        VStack(alignment: .leading, spacing: 18) {
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

            // Emoji + 颜色
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel(Copy.Stamps.fieldEmojiColor(lang))
                HStack(spacing: 16) {
                    livePreview
                    VStack(alignment: .leading, spacing: 8) {
                        emojiPicker
                        tintPicker
                    }
                }
            }

            // Prompt 内容
            VStack(alignment: .leading, spacing: 6) {
                sectionLabel(Copy.Stamps.fieldBody(lang))
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
                .frame(minHeight: 140)
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

    // MARK: - Live preview

    private var livePreview: some View {
        PromptStampChip(
            stamp: PromptStamp(title: title, body: body_, emoji: emoji, tint: tint),
            size: .large,
            rotated: true
        )
        .padding(.horizontal, 6)
    }

    // MARK: - Emoji picker

    private var emojiPicker: some View {
        HStack(spacing: 4) {
            ForEach(Self.emojiPresets, id: \.self) { e in
                Button(action: { emoji = e }) {
                    Text(e)
                        .font(.system(size: 18))
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(emoji == e ? Color.piloGold.opacity(0.18) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(
                                    emoji == e ? Color.piloGold.opacity(0.6) : Color.clear,
                                    lineWidth: 0.8
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Tint picker

    private var tintPicker: some View {
        HStack(spacing: 5) {
            ForEach(PromptStamp.StampTint.allCases, id: \.self) { t in
                Button(action: { tint = t }) {
                    Circle()
                        .fill(t.color)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(
                                    tint == t ? Color.piloGoldDark : Color.clear,
                                    lineWidth: 1.5
                                )
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .help(t.labelZH)
            }
        }
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
                emoji: emoji,
                tint: tint,
                pinned: pinned
            )
            appState.addPromptStamp(stamp)
        } else {
            var updated = initial
            updated.title = trimmedTitle
            updated.body = trimmedBody
            updated.emoji = emoji
            updated.tint = tint
            updated.pinned = pinned
            appState.updatePromptStamp(updated)
        }
        appState.closeStampEditor()
    }
}
