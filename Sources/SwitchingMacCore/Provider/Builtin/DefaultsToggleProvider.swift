import Foundation

/// `defaults` コマンドで真偽値の環境設定を書き換えるスイッチ。
///
/// Finder や Dock は設定を読み直さないため、書き換え後に対象プロセスを再起動する。
public struct DefaultsToggleProvider: SwitchProvider {
    private static let defaultsPath = "/usr/bin/defaults"
    private static let killallPath = "/usr/bin/killall"
    private static let trueOutputs: Set<String> = ["1", "true", "YES"]

    public let kind: SwitchKind
    private let domain: String
    private let key: String
    /// 設定反映のために再起動するプロセス名
    private let processToRestart: String?
    /// キーが未設定のときの OS 既定値
    private let fallbackValue: Bool
    private let runner: any CommandRunning

    public init(
        kind: SwitchKind,
        domain: String,
        key: String,
        processToRestart: String?,
        fallbackValue: Bool,
        runner: any CommandRunning
    ) {
        self.kind = kind
        self.domain = domain
        self.key = key
        self.processToRestart = processToRestart
        self.fallbackValue = fallbackValue
        self.runner = runner
    }

    /// Finder の隠しファイル表示
    public static func hiddenFiles(runner: any CommandRunning) -> DefaultsToggleProvider {
        DefaultsToggleProvider(
            kind: .hiddenFiles,
            domain: "com.apple.finder",
            key: "AppleShowAllFiles",
            processToRestart: "Finder",
            fallbackValue: false,
            runner: runner
        )
    }

    /// Dock の自動的に非表示
    public static func dockAutohide(runner: any CommandRunning) -> DefaultsToggleProvider {
        DefaultsToggleProvider(
            kind: .dockAutohide,
            domain: "com.apple.dock",
            key: "autohide",
            processToRestart: "Dock",
            fallbackValue: false,
            runner: runner
        )
    }

    public var availability: ProviderAvailability {
        .requiresFullAccess(reason: "他アプリの環境設定の書き換えはサンドボックスでは行えません。")
    }

    public func readState(_ context: SwitchContext) async -> SwitchState {
        guard let result = try? await runner.run(
            .tool(Self.defaultsPath, ["read", domain, key])
        ) else {
            return .unknown
        }
        // キーが未設定のときは失敗するので、OS の既定値を返す。
        guard result.isSuccess else { return .from(isOn: fallbackValue) }
        return .from(isOn: Self.trueOutputs.contains(result.trimmedOutput))
    }

    public func apply(isOn: Bool, context: SwitchContext) async throws {
        try await runner.runExpectingSuccess(
            .tool(Self.defaultsPath, ["write", domain, key, "-bool", isOn ? "YES" : "NO"])
        )

        guard let processToRestart else { return }
        // 再起動の失敗（対象プロセスが動いていない等）は設定変更自体を妨げないため無視する。
        _ = try? await runner.run(.tool(Self.killallPath, [processToRestart]))
    }
}
