import SwiftUI

// MARK: - PrivacyPill（右上角 私有 / 公开）

/// 仓库可见性指示。位置：详情页 title 行右上。
/// **真实**用 GitHub 公共 API 查（GitHubVisibilityClient），24h 缓存。
/// 三态：公开 / 私有 / unknown（未查到时 = nil，不显示 pill）。
struct PrivacyPill: View {
    let repoId: UUID
    @Environment(AppState.self) private var appState

    private var lang: Language { appState.language }

    var body: some View {
        switch appState.cachedVisibility(for: repoId) {
        case .publicRepo:
            pill(text: lang == .zh ? "公开" : "Public",
                 fg: Color.roseDanger,
                 bg: Color.piloAccent.opacity(0.22))
        case .privateRepo:
            pill(text: lang == .zh ? "私有" : "Private",
                 fg: Color.inkSecondary,
                 bg: Color.cloudDivider.opacity(0.55))
        case .unknown, .none:
            // 未查到/查不到——保持沉默，不假装知道
            EmptyView()
        }
    }

    private func pill(text: String, fg: Color, bg: Color) -> some View {
        Text(text)
            .font(.piloSerifSubtitle)
            .foregroundStyle(fg)
            .padding(.horizontal, 11)
            .padding(.vertical, 4)
            .background(bg, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

// MARK: - RepoStatusPill（path 下方大状态药丸）

/// 仓库整体状态，按优先级：uncommitted > ahead > synced。
/// 三种 tint：
///   - ahead（金棕 on cream paper）："N 个待推送 commit"
///   - uncommitted（rose）："N 个未提交变更"
///   - synced（mint）："已同步"
struct RepoStatusPill: View {
    let repo: Repository
    @Environment(AppState.self) private var appState

    private var lang: Language { appState.language }

    var body: some View {
        let style = pillStyle()
        return Text(style.text)
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(style.fg)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(style.bg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(style.border, lineWidth: 0.5)
            )
    }

    private func pillStyle() -> (text: String, bg: Color, fg: Color, border: Color) {
        // 注意顺序：uncommitted 优先级最高（"先提交才能推"），其次 ahead，最后 synced
        if repo.aheadCount == 0 && repo.uncommittedCount > 0 {
            let text = lang == .zh
                ? "\(repo.uncommittedCount) 个未提交变更"
                : "\(repo.uncommittedCount) uncommitted change\(repo.uncommittedCount == 1 ? "" : "s")"
            return (text,
                    Color.roseDanger.opacity(0.10),
                    Color.roseDanger,
                    Color.roseDanger.opacity(0.30))
        }
        if repo.aheadCount > 0 {
            let text = lang == .zh
                ? "\(repo.aheadCount) 个待推送 commit"
                : "\(repo.aheadCount) commit\(repo.aheadCount == 1 ? "" : "s") to push"
            return (text,
                    Color.piloPaper,
                    Color.piloGoldDark,
                    Color.piloPaperBorder)
        }
        let text = lang == .zh ? "已同步" : "Synced"
        return (text,
                Color.mintSafe.opacity(0.18),
                Color.stampMint,
                Color.mintSafe.opacity(0.45))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 14) {
        HStack {
            Text("uvpeek-android").font(.piloSerifHero)
            Spacer()
            PrivacyPill(repoId: UUID())
        }
        HStack {
            Text("my-blog").font(.piloSerifHero)
            Spacer()
            PrivacyPill(repoId: UUID())
        }
    }
    .padding(28)
    .background(Color.paperCard)
}
