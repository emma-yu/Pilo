import SwiftUI

/// 版本通告信 reader —— 跟 LetterReaderView 平级，视觉差异化：
///   - 标题用「邮局通告」+ 版本号；Songti SC 32pt 加大隆重感
///   - 信纸顶部右上角红蜡封 + scroll icon（仪式感）
///   - 内容结构：标题 → 亮点 bullets → 长段落 body → 落款"Pilo 邮局总局"
///   - 跟 DailyLetter 同一 cream paper 信纸基底，保持邮局美学一致
struct ReleaseLetterReaderView: View {

    let letter: ReleaseLetter

    @Environment(AppState.self) private var appState
    @Environment(\.tone) private var tone
    private var lang: Language { appState.language }

    /// 守门 —— SwiftUI 会在 sheet 重叠 / Stage Manager 切换 / 父 view 重渲染时
    /// 多次 fire `onAppear`，没这个 guard 会反复重播 waxSealCrack。
    /// `@State` 跟 view 实例 lifetime 绑定：sheet 关闭重开会 reset；同一次 sheet
    /// 期间的多次 onAppear 都 guard 住，只播一次。
    @State private var hasPlayedSeal = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Rectangle()
                .fill(Color.piloGold.opacity(0.4))
                .frame(height: 0.5)
            ScrollView {
                content
                    .padding(.horizontal, 48)
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 640, height: 720)
        .background(Color.piloPaper.opacity(0.95))
        .onAppear {
            guard !hasPlayedSeal else { return }
            hasPlayedSeal = true
            // 蜡封 crack —— 仅首次开启未读时响（已读再开静默）
            let wasUnread = letter.isUnread
            appState.markReleaseLetterRead(letter)
            if wasUnread { appState.soundPlayer.play(.waxSealCrack) }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "scroll.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.stampRed)
            Text("v\(letter.version)")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.inkPrimary)
            if letter.isUnread {
                Text(Copy.Letter.unreadBadge(lang))
                    .font(.piloSerifCaption)
                    .italic()
                    .foregroundStyle(Color.stampRed)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(Color.stampRed.opacity(0.5), lineWidth: 0.5)
                    )
            }
            Spacer()
            Button(action: { appState.closeReadingReleaseLetter() }) {
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

    // MARK: - Letter content

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header —— "邮局通告" 大标题 + 右上 PostalDial 邮戳水印
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Copy.Letter.releaseLetterHeader(lang))
                        .font(.custom("Songti SC", size: 30).weight(.medium))
                        .foregroundStyle(Color.inkPrimary)
                    OrnamentDivider(width: 180)
                }
                Spacer()
                // 用 WaxSealPilo 而不是 PostalDial —— 通告比日报更"正式"，蜡封感更隆重
                Image("WaxSealPilo")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 76, height: 76)
                    .rotationEffect(.degrees(-6))
                    .opacity(0.82)
                    .blendMode(.multiply)
                    .offset(y: -6)
            }
            .padding(.bottom, 4)

            // 副标题（letter.title） + 版本日期
            VStack(alignment: .leading, spacing: 4) {
                Text(letter.title)
                    .font(.custom("Songti SC", size: 20).weight(.medium))
                    .foregroundStyle(Color.inkPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(Self.dateFormatter.string(from: letter.releaseDate) + " · v\(letter.version)")
                    .font(.piloSerifCaption)
                    .italic()
                    .foregroundStyle(Color.inkSecondary)
            }

            // Highlights —— bullet 列表
            if !letter.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(Copy.Letter.releaseHighlightsLabel(lang))
                        .font(.piloSerifLabel)
                        .foregroundStyle(Color.piloGoldDark)
                        .tracking(1.5)
                        .padding(.top, 8)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(letter.highlights.enumerated()), id: \.offset) { _, line in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("·")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.piloGoldDark.opacity(0.7))
                                    .frame(width: 8)
                                Text(line)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.inkPrimary)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.leading, 4)
                }
            }

            // Body 段落
            if !letter.bodyParagraphs.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(letter.bodyParagraphs.enumerated()), id: \.offset) { _, para in
                        Text(para)
                            .font(.custom("Songti SC", size: 16))
                            .foregroundStyle(Color.inkPrimary)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 10)
            }

            // 落款
            Text(Copy.Letter.releaseLetterSignature(lang))
                .font(.custom("Songti SC", size: 18).italic())
                .foregroundStyle(Color.piloGoldDark)
                .padding(.top, 12)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
