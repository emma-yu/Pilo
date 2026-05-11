import Foundation

/// 包装 `git` 子进程的薄层。所有命令都强制：
///   - LANG/LC_ALL = C.UTF-8 ：保持输出可解析（避免本地化"位于分支 main"）
///   - GIT_TERMINAL_PROMPT = 0 ：fetch/push 永不交互式问凭证，超时干净
///   - GIT_OPTIONAL_LOCKS = 0 ：只读操作不创建 .git/index.lock
/// 所有 Process 都显式 Pipe() 三路 stream（Phase 5 push 凭证交互依赖 stdin）。
actor GitClient {

    private(set) var executablePath: String?
    private(set) var version: String?

    struct ProcessResult: Sendable {
        let stdout: String
        let stderr: String
        let exitCode: Int32
        var ok: Bool { exitCode == 0 }
    }

    enum GitError: Error {
        case notInstalled
        case nonZeroExit(stderr: String, code: Int32)
        case timedOut
    }

    // MARK: - 启动检测

    func detect() async {
        let candidates = [
            "/opt/homebrew/bin/git",
            "/usr/local/bin/git",
            "/usr/bin/git",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            executablePath = path
            break
        }
        if executablePath == nil {
            // fallback: 用 /usr/bin/which 在登录 shell 的 PATH 里找
            if let resolved = await runOnce("/usr/bin/which", args: ["git"]),
               resolved.ok,
               !resolved.stdout.isEmpty {
                let p = resolved.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                if FileManager.default.isExecutableFile(atPath: p) {
                    executablePath = p
                }
            }
        }
        if let exec = executablePath,
           let v = await runOnce(exec, args: ["--version"]),
           v.ok {
            version = v.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // MARK: - 仓库查询 API

    func currentBranch(repo: URL) async -> String? {
        guard let r = await runGit(["symbolic-ref", "--short", "HEAD"], in: repo) else { return nil }
        if r.ok {
            return r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil   // detached HEAD 或其它情况，v0.1 直接当作"无分支"
    }

    func uncommittedCount(repo: URL) async -> Int {
        guard let r = await runGit(["status", "--porcelain"], in: repo), r.ok else { return 0 }
        let lines = r.stdout.split(separator: "\n", omittingEmptySubsequences: true)
        return lines.count
    }

    /// 返回 (ahead, behind)。若 remote 引用不存在（本地未 fetch 过），返回 (0, 0)。
    func aheadBehind(repo: URL, branch: String, remote: String = "origin") async -> (ahead: Int, behind: Int) {
        let ref = "\(remote)/\(branch)"
        // 先检查 remote ref 是否存在
        guard let exists = await runGit(["rev-parse", "--verify", "--quiet", ref], in: repo),
              exists.ok else { return (0, 0) }
        guard let r = await runGit(["rev-list", "--left-right", "--count", "\(ref)...HEAD"], in: repo),
              r.ok else { return (0, 0) }
        // 输出格式: "<behind>\t<ahead>"
        let parts = r.stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\t")
        guard parts.count == 2,
              let behind = Int(parts[0]),
              let ahead = Int(parts[1]) else { return (0, 0) }
        return (ahead, behind)
    }

    func remotes(repo: URL) async -> [GitRemote] {
        guard let r = await runGit(["remote", "-v"], in: repo), r.ok else { return [] }
        // 每个 remote 有两行（fetch / push），name+url 相同，去重
        var map: [String: String] = [:]
        for line in r.stdout.split(separator: "\n") {
            let cols = line.split(separator: "\t", omittingEmptySubsequences: true)
            guard cols.count >= 2 else { continue }
            let name = String(cols[0])
            let urlAndKind = String(cols[1])
            let url = String(urlAndKind.split(separator: " ").first ?? "")
            if map[name] == nil { map[name] = url }
        }
        return map
            .sorted { lhs, rhs in
                // origin 永远在最前
                if lhs.key == "origin" { return true }
                if rhs.key == "origin" { return false }
                return lhs.key < rhs.key
            }
            .map { GitRemote(name: $0.key, url: $0.value, isPublic: nil) }
    }

    func lastCommitDate(repo: URL) async -> Date? {
        guard let r = await runGit(["log", "-1", "--format=%ct"], in: repo), r.ok else { return nil }
        let s = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let ts = TimeInterval(s) else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    func firstCommitHash(repo: URL) async -> String? {
        guard let r = await runGit(["rev-list", "--max-parents=0", "HEAD"], in: repo), r.ok else { return nil }
        // 多个根 commit 时取第一行
        let first = r.stdout.split(separator: "\n").first.map(String.init) ?? ""
        let trimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Push 相关查询

    /// 当前分支的 upstream，例如 `origin/main`。无配置返回 nil。
    func branchUpstream(repo: URL, branch: String) async -> (remote: String, branch: String)? {
        guard let r = await runGit(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "\(branch)@{upstream}"], in: repo),
              r.ok else { return nil }
        let s = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = s.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        return (parts[0], parts[1])
    }

    /// 列出从 `<remote>/<branch>` 到 `HEAD` 之间未推送的 commit。
    /// 若 remote ref 不存在，返回空数组（调用方应改走"首次 push -u"路径）。
    func pendingPushCommits(repo: URL, branch: String, remote: String) async -> [CommitSummary] {
        let ref = "\(remote)/\(branch)"
        // remote ref 不存在直接 short-circuit
        guard let exists = await runGit(["rev-parse", "--verify", "--quiet", ref], in: repo),
              exists.ok else { return [] }

        // %x00 是 NUL 分隔符；%h short hash；%s subject；%ct epoch；%an author name
        let format = "%h%x00%s%x00%ct%x00%an"
        guard let r = await runGit(
            ["log", "\(ref)..HEAD", "--format=\(format)"],
            in: repo
        ), r.ok else { return [] }

        var out: [CommitSummary] = []
        for line in r.stdout.split(separator: "\n", omittingEmptySubsequences: true) {
            let cols = line.split(separator: "\0", omittingEmptySubsequences: false).map(String.init)
            guard cols.count == 4 else { continue }
            guard let ts = TimeInterval(cols[2]) else { continue }
            out.append(CommitSummary(
                hash: cols[0],
                subject: cols[1],
                date: Date(timeIntervalSince1970: ts),
                author: cols[3]
            ))
        }
        return out
    }

    /// 拉取即将 push 的 commit 范围内变更过的文件清单 + status。
    /// 返回 [(path, status)]，status: A/M/D；删除项调用方应跳过 size 检查。
    /// 首次 push（远端 ref 不存在）时和空树对比，得到 HEAD 全量文件清单（全部当 A）。
    func changedFilesForPush(repo: URL, branch: String, remote: String) async -> [(path: String, status: Character)] {
        let ref = "\(remote)/\(branch)"
        let exists = await runGit(["rev-parse", "--verify", "--quiet", ref], in: repo)
        let revSpec: String
        if exists?.ok == true {
            revSpec = "\(ref)..HEAD"
        } else {
            revSpec = "4b825dc642cb6eb9a060e54bf8d69288fbee4904..HEAD"
        }
        guard let r = await runGit(["diff", "--name-status", "-M", "-C", revSpec], in: repo), r.ok else {
            return []
        }
        var out: [(String, Character)] = []
        for line in r.stdout.split(separator: "\n", omittingEmptySubsequences: true) {
            // 形如 "A\tpath" 或 "M\tpath" 或 "R100\told\tnew"（rename）
            let cols = line.split(separator: "\t", omittingEmptySubsequences: true).map(String.init)
            guard let first = cols.first, !first.isEmpty else { continue }
            let status = first.first!
            // rename / copy 取目标路径（最后一列）
            if (status == "R" || status == "C"), cols.count >= 3 {
                out.append((cols[2], "A"))    // 重命名后的目标当 A 处理
            } else if cols.count >= 2 {
                out.append((cols[1], status))
            }
        }
        return out
    }

    /// 查 HEAD 上某个 path 的 blob 大小（bytes）。
    /// 文件不存在 / 是子模块时返回 nil。
    func blobSize(repo: URL, path: String) async -> Int64? {
        // git cat-file -s HEAD:<path>
        guard let r = await runGit(["cat-file", "-s", "HEAD:\(path)"], in: repo), r.ok else { return nil }
        return Int64(r.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// 拉取即将推送的 diff（HEAD vs 远端分支）。--unified=0 让我们只看到真新增的行，
    /// 不带上下文 noise；--no-color 关掉 ANSI 转义；--no-ext-diff 防御用户配了花式 differ。
    /// 远端 ref 不存在（首次 push）时返回 HEAD 的全量内容 diff。
    func diffForPush(repo: URL, branch: String, remote: String) async -> String? {
        let ref = "\(remote)/\(branch)"
        let exists = await runGit(["rev-parse", "--verify", "--quiet", ref], in: repo)
        let revisionSpec: String
        if exists?.ok == true {
            revisionSpec = "\(ref)..HEAD"
        } else {
            // 首次 push：和"空树"对比 → diff 出 HEAD 的全量内容
            revisionSpec = "4b825dc642cb6eb9a060e54bf8d69288fbee4904..HEAD"
            // ↑ 这是 git 的 well-known 空树 hash (`git hash-object -t tree --stdin </dev/null`)
        }
        let r = await runGitWithTimeout(
            ["diff", revisionSpec, "--unified=0", "--no-color", "--no-ext-diff"],
            in: repo,
            timeout: 30
        )
        guard let r, r.ok else { return nil }
        return r.stdout
    }

    /// 执行 `git push`。**不解释结果**——调用方（PushExecutor）负责 stderr 分类。
    /// 已经强制 GIT_TERMINAL_PROMPT=0；凭证缺失时会立刻失败而非阻塞。
    func push(repo: URL, remote: String, branch: String, setUpstream: Bool) async -> ProcessResult? {
        var args = ["push", "--porcelain"]
        if setUpstream { args.append("-u") }
        args.append(remote)
        args.append(branch)
        // push 可能较慢；放宽 timeout 到 120s
        return await runGitWithTimeout(args, in: repo, timeout: 120)
    }

    // MARK: - 内部进程执行

    private func runGit(_ args: [String], in repo: URL) async -> ProcessResult? {
        guard let exec = executablePath else { return nil }
        return await runOnce(exec, args: args, workingDirectory: repo)
    }

    private func runGitWithTimeout(_ args: [String], in repo: URL, timeout: TimeInterval) async -> ProcessResult? {
        guard let exec = executablePath else { return nil }
        return await runOnce(exec, args: args, workingDirectory: repo, timeout: timeout)
    }

    private func runOnce(
        _ path: String,
        args: [String],
        workingDirectory: URL? = nil,
        timeout: TimeInterval = 15
    ) async -> ProcessResult? {
        await withCheckedContinuation { (cont: CheckedContinuation<ProcessResult?, Never>) in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            let stdinPipe = Pipe()    // Phase 5 push 凭证交互的伏笔

            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = args
            if let workingDirectory {
                process.currentDirectoryURL = workingDirectory
            }

            var env = ProcessInfo.processInfo.environment
            env["LANG"] = "C.UTF-8"
            env["LC_ALL"] = "C.UTF-8"
            env["GIT_TERMINAL_PROMPT"] = "0"
            env["GIT_OPTIONAL_LOCKS"] = "0"
            process.environment = env

            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            process.standardInput = stdinPipe

            // 用 nonisolated 局部状态 + actor-isolated 不可达的方式避免 Swift 6 数据竞争
            let box = ContinuationBox(cont: cont)

            process.terminationHandler = { proc in
                let outData = (try? stdoutPipe.fileHandleForReading.readToEnd()) ?? Data()
                let errData = (try? stderrPipe.fileHandleForReading.readToEnd()) ?? Data()
                let result = ProcessResult(
                    stdout: String(data: outData, encoding: .utf8) ?? "",
                    stderr: String(data: errData, encoding: .utf8) ?? "",
                    exitCode: proc.terminationStatus
                )
                box.resume(result)
            }

            do {
                try process.run()
            } catch {
                box.resume(nil)
                return
            }

            // timeout watchdog
            Task.detached {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if process.isRunning {
                    process.terminate()
                }
            }
        }
    }
}

/// 用一个引用包裹 continuation，保证 termination handler / timeout 只 resume 一次。
private final class ContinuationBox: @unchecked Sendable {
    private var continuation: CheckedContinuation<GitClient.ProcessResult?, Never>?
    private let lock = NSLock()

    init(cont: CheckedContinuation<GitClient.ProcessResult?, Never>) {
        self.continuation = cont
    }

    func resume(_ value: GitClient.ProcessResult?) {
        lock.lock(); defer { lock.unlock() }
        guard let c = continuation else { return }
        continuation = nil
        c.resume(returning: value)
    }
}
