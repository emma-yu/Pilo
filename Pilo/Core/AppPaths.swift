import Foundation

/// 应用所有文件系统位置的单一来源。
///
/// 当前 v0.1 关闭沙盒：state.json 写到未沙盒化的规范位置
/// `~/Library/Application Support/Pilo/state.json`。
/// 如果未来需要开启 Mac App Store 沙盒，路径会变成 Container 内部，
/// `migrateFromLegacyLocation()` 负责一次性搬运。
enum AppPaths {

    static var applicationSupport: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Pilo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var stateJSON: URL {
        applicationSupport.appendingPathComponent("state.json", isDirectory: false)
    }

    /// 信件箱：每日邮局生成的历史信件
    static var lettersJSON: URL {
        applicationSupport.appendingPathComponent("letters.json", isDirectory: false)
    }

    /// 版本通告信箱：Pilo 每发新版投递的"邮局通告"信
    static var releaseLettersJSON: URL {
        applicationSupport.appendingPathComponent("release-letters.json", isDirectory: false)
    }

    static var logsDir: URL {
        let base = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Logs/Pilo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 未来开沙盒时调用。当前仅占位。
    static func migrateFromLegacyLocation() {
        // TODO: 当切到沙盒后，把数据从 ~/Library/Application Support/Pilo
        // 搬到 ~/Library/Containers/dev.pilo.Pilo/Data/Library/Application Support/Pilo
    }
}
