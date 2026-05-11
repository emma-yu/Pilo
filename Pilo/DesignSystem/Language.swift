import SwiftUI
import Foundation

/// 应用界面语言。v0.1 支持两种：
/// - `.zh` 简体中文：面向中文用户，融入当代温柔可爱网络语言（但避开易过气梗）
/// - `.en` English：面向全球，friendly + 克制，pigeon/letter metaphor
enum Language: String, CaseIterable, Sendable, Codable {
    case zh
    case en

    /// 自身语言里的显示名（永远展示原语言名，不翻译）
    var nativeName: String {
        switch self {
        case .zh: return "简体中文"
        case .en: return "English"
        }
    }

    /// 用于无障碍 / 调试
    var englishName: String {
        switch self {
        case .zh: return "Chinese (Simplified)"
        case .en: return "English"
        }
    }

    /// 按系统 Locale 推断默认语言
    static var systemDefault: Language {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        if code.lowercased().hasPrefix("zh") { return .zh }
        return .en
    }
}

private struct LanguageEnvironmentKey: EnvironmentKey {
    static let defaultValue: Language = .zh
}

extension EnvironmentValues {
    var language: Language {
        get { self[LanguageEnvironmentKey.self] }
        set { self[LanguageEnvironmentKey.self] = newValue }
    }
}

extension View {
    func language(_ lang: Language) -> some View {
        environment(\.language, lang)
    }
}
