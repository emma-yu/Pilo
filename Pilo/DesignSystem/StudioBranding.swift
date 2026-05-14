import Foundation

/// 跨产品署名 / 工作室引导用到的非文案常量。
///
/// 文案不放这——全部走 `Copy.Studio.*`，保持「所有面向用户字符串集中在 Copy.swift」
/// 这条 CLAUDE.md 房规不破。这里只放 URL 这种「非可本地化」的硬常量。
enum StudioBranding {
    /// 工作室官网 —— 关于页 + 收件箱便条卡的「访问」按钮目标。
    /// 用户对 UVPeek 的兴趣也通过这里走（站内会有 UVPeek 介绍），
    /// 不单独维护 uvpeekURL 是为了避免「指向不可达 / 文案分歧」风险。
    static let studioURL = URL(string: "https://xinxinmingde.com")!
}
