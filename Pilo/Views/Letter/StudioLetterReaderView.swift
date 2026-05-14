import SwiftUI

/// 总局来信 reader —— 跟 ReleaseLetterReaderView 平级，视觉差异化：
///   - 标题「总局来信」（不是「邮局通告」）
///   - toolbar / header 用 `building.columns.fill` + piloGoldDark（金色集团徽，
///     跟 release letter 的红蜡封形成「同形不同色」视觉家族）
///   - 落款 "新欣明德设计工作室 敬上"
///   - 可选 CTA 按钮（如「去看看 UVPeek」）夹在 body 和落款之间
///
/// 跟 release reader 一样，开启 view 即标已读 + 持久化。
struct StudioLetterReaderView: View {

    let letter: StudioLetter

    @Environment(AppState.self) private var appState
    private var lang: Language { appState.language }

    @State private var hasMarkedRead = false

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
            guard !hasMarkedRead else { return }
            hasMarkedRead = true
            appState.markStudioLetterRead(letter)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.piloGoldDark)
            Text(Copy.Letter.studioRowHeader(lang))
                .font(.piloSerifCaption)
                .foregroundStyle(Color.inkPrimary)
            if letter.isUnread {
                Text(Copy.Letter.unreadBadge(lang))
                    .font(.piloSerifCaption)
                    .italic()
                    .foregroundStyle(Color.piloGoldDark)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(Color.piloGoldDark.opacity(0.5), lineWidth: 0.5)
                    )
            }
            Spacer()
            Button(action: { appState.closeReadingStudioLetter() }) {
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
            // Header
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Copy.Letter.studioLetterHeader(lang))
                        .font(.custom("Songti SC", size: 30).weight(.medium))
                        .foregroundStyle(Color.inkPrimary)
                    OrnamentDivider(width: 180)
                }
                Spacer()
                // 金色集团徽（SF Symbol，跟 release 的 WaxSealPilo asset 区分）
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(Color.piloGoldDark.opacity(0.78))
                    .rotationEffect(.degrees(-6))
                    .offset(y: 2)
            }
            .padding(.bottom, 4)

            // Subtitle: title + sent date
            VStack(alignment: .leading, spacing: 4) {
                Text(letter.title)
                    .font(.custom("Songti SC", size: 20).weight(.medium))
                    .foregroundStyle(Color.inkPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(Self.dateFormatter.string(from: letter.sentDate))
                    .font(.piloSerifCaption)
                    .italic()
                    .foregroundStyle(Color.inkSecondary)
            }

            // Highlights
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

            // Body
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

            // 可选 CTA（如指向 UVPeek 官网）
            if let cta = letter.cta {
                HStack {
                    Button {
                        NSWorkspace.shared.open(cta.url)
                    } label: {
                        HStack(spacing: 5) {
                            Text(cta.label)
                                .font(.piloSection)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .buttonStyle(.piloSecondary)
                    Spacer()
                }
                .padding(.top, 12)
            }

            // 落款 + 装饰金线
            VStack(alignment: .leading, spacing: 10) {
                Text(Copy.Letter.studioLetterSignature(lang))
                    .font(.custom("Songti SC", size: 18).italic())
                    .foregroundStyle(Color.piloGoldDark)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.piloGold.opacity(0),
                                Color.piloGold.opacity(0.5),
                                Color.piloGold.opacity(0),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 90, height: 0.6)
            }
            .padding(.top, 12)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
