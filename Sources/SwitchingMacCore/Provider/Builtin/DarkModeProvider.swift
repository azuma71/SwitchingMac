import Foundation

/// システム外観のライト / ダークを切り替える。
///
/// 状態は `defaults read -g AppleInterfaceStyle` で読み取り、
/// 変更は「システムイベント」への Apple Event で行う。
/// 初回実行時に自動化の許可ダイアログが表示される。
public struct DarkModeProvider: SwitchProvider {
    private static let defaultsPath = "/usr/bin/defaults"
    private static let osascriptPath = "/usr/bin/osascript"
    private static let darkStyleValue = "Dark"

    private let runner: any CommandRunning

    public init(runner: any CommandRunning) {
        self.runner = runner
    }

    public var kind: SwitchKind { .darkMode }

    public var availability: ProviderAvailability {
        .requiresFullAccess(reason: "システムイベントの操作許可が必要なため、サンドボックス版では利用できません。")
    }

    public func readState(_ context: SwitchContext) async -> SwitchState {
        // ライトモードではキー自体が存在せず、終了コードが 0 以外になる。
        guard let result = try? await runner.run(
            .tool(Self.defaultsPath, ["read", "-g", "AppleInterfaceStyle"])
        ) else {
            return .unknown
        }
        guard result.isSuccess else { return .off }
        return .from(isOn: result.trimmedOutput == Self.darkStyleValue)
    }

    public func apply(isOn: Bool, context: SwitchContext) async throws {
        let script = """
        tell application "System Events" to tell appearance preferences \
        to set dark mode to \(isOn ? "true" : "false")
        """
        do {
            try await runner.runExpectingSuccess(.tool(Self.osascriptPath, ["-e", script]))
        } catch let error as SwitchError {
            throw Self.mapToPermissionErrorIfNeeded(error)
        }
    }

    /// 自動化の許可が下りていない場合は、対処方法が分かるエラーへ読み替える。
    private static func mapToPermissionErrorIfNeeded(_ error: SwitchError) -> SwitchError {
        guard case let .commandFailed(_, _, message) = error,
              message.contains("-1743") || message.lowercased().contains("not allowed")
        else {
            return error
        }
        return .permissionDenied(
            reason: "「システム設定 > プライバシーとセキュリティ > オートメーション」で "
                + "SwitchingMac に「システムイベント」の操作を許可してください。"
        )
    }
}
