import SwiftUI

/// 「新版本已发车」推送信 reader —— 跟 ReleaseLetterReaderView 设计语言一致，但
/// 多了**核心 CTA「下载新版本」按钮**（蓝色 piloPrimary，最显眼）。
///
/// 跟 ReleaseLetter（已升级后的回顾）的区别：
///   - 这个是**引导动作**：用户在老版本，需要打开浏览器下载
///   - 视觉用 **PostalPlane 邮政小飞机** asset（"已发车"的意象）替代 WaxSealPilo
///   - 多一个「以后再说」次要按钮，让用户能 dismiss（不喜欢可清）
struct UpdateAvailableReaderView: View {

    let letter: UpdateAvailableLetter

    @Environment(AppState.self) private var appState
    @Environment(\.tone) private var tone
    private var lang: Language { appState.language }

    /// 守门 —— SwiftUI 会在 sheet 重叠 / 窗口 active 切换 / 父 view 重渲染时
    /// 多次 fire `onAppear`，没这个 guard 会反复重播 waxSealCrack。
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
            // 蜡封 crack —— 仅首次开启未读时响
            let wasUnread = letter.isUnread
            appState.markUpdateLetterRead(letter)
            if wasUnread { appState.soundPlayer.play(.waxSealCrack) }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.piloBlue)
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
            Button(action: { appState.closeReadingUpdateLetter() }) {
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
            // Header —— 「邮局新车已发」+ 邮政小飞机 asset 右上
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Copy.Letter.updateLetterHeader(lang))
                        .font(.custom("Songti SC", size: 30).weight(.medium))
                        .foregroundStyle(Color.inkPrimary)
                    OrnamentDivider(width: 180)
                }
                Spacer()
                Image("PostalPlane")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 84, height: 84)
                    .rotationEffect(.degrees(-12))   // 略夸张倾角 —— "起飞"动感
                    .opacity(0.88)
                    .blendMode(.multiply)
                    .offset(y: -8)
            }
            .padding(.bottom, 4)

            // 副标题：letter.title / letter.enTitle
            let displayTitle = (lang == .en ? letter.enTitle : nil) ?? letter.title
            let displayHighlights = (lang == .en ? letter.enHighlights : nil) ?? letter.highlights

            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .font(.custom("Songti SC", size: 20).weight(.medium))
                    .foregroundStyle(Color.inkPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(Self.dateFormatter.string(from: letter.releaseDate) + " · v\(letter.version)")
                    .font(.piloSerifCaption)
                    .italic()
                    .foregroundStyle(Color.inkSecondary)
            }

            // CTA 区 —— 「下载新版本」蓝色 primary + 「以后再说」次要 ghost
            ctaButtons

            // Highlights bullets
            if !displayHighlights.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(Copy.Letter.releaseHighlightsLabel(lang))
                        .font(.piloSerifLabel)
                        .foregroundStyle(Color.piloGoldDark)
                        .tracking(1.5)
                        .padding(.top, 8)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(displayHighlights.enumerated()), id: \.offset) { _, line in
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

            // 落款
            Text(Copy.Letter.releaseLetterSignature(lang))
                .font(.custom("Songti SC", size: 18).italic())
                .foregroundStyle(Color.piloGoldDark)
                .padding(.top, 12)
        }
    }

    @ViewBuilder
    private var ctaButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 主 CTA: 下载新版本
            Button {
                appState.downloadUpdate(letter)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 13))
                    Text(Copy.Letter.updateDownloadCTA(lang))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
            }
            .buttonStyle(.piloPrimary)
            .help(letter.downloadURL.absoluteString)

            // 次要：在浏览器看完整 release notes（如果 manifest 提供）
            if let notesURL = letter.releaseNotesURL {
                Button {
                    NSWorkspace.shared.open(notesURL)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 11))
                        Text(Copy.Letter.updateViewNotesCTA(lang))
                            .font(.piloSerifCaption)
                    }
                    .foregroundStyle(Color.piloBlueDark)
                }
                .buttonStyle(.plain)
            }

            // 次要：以后再说
            Button {
                appState.dismissUpdateLetter()
            } label: {
                Text(Copy.Letter.updateDismissCTA(lang))
                    .font(.piloSerifCaption)
                    .italic()
                    .foregroundStyle(Color.inkTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
