import Foundation

/// 蓋を閉じてもスリープしないようにする（システム全体のスリープ無効化）。
///
/// `IOPMAssertion` では蓋を閉じたときのスリープは抑止できないため、
/// `pmset -a disablesleep` を使う。この変更には管理者権限が必要なので、
/// 切り替えのたびに認証ダイアログが表示される。状態の読み取りに権限は不要。
public struct PreventLidSleepProvider: SwitchProvider {
    private static let pmsetPath = "/usr/bin/pmset"
    private static let osascriptPath = "/usr/bin/osascript"
    /// `pmset -g` の出力でスリープ無効化を表すキー
    private static let sleepDisabledKey = "SleepDisabled"
    /// 認証ダイアログをキャンセルしたときに AppleScript が返すエラー
    private static let userCancelledMarkers = ["-128", "User canceled"]

    private let runner: any CommandRunning

    public init(runner: any CommandRunning) {
        self.runner = runner
    }

    public var kind: SwitchKind { .preventLidSleep }

    public var availability: ProviderAvailability {
        .requiresFullAccess(reason: "システム全体の電源設定の変更には管理者権限が必要なため、サンドボックス版では利用できません。")
    }

    public func readState(_ context: SwitchContext) async -> SwitchState {
        guard let result = try? await runner.run(.tool(Self.pmsetPath, ["-g"])),
              result.isSuccess
        else {
            return .unknown
        }
        return .from(isOn: Self.parseSleepDisabled(from: result.standardOutput))
    }

    public func apply(isOn: Bool, context: SwitchContext) async throws {
        // 埋め込む値は真偽値から導出したリテラルのみで、外部入力は連結しない。
        let script = "do shell script \"\(Self.pmsetPath) -a disablesleep \(isOn ? 1 : 0)\" "
            + "with administrator privileges"
        do {
            try await runner.runExpectingSuccess(.tool(Self.osascriptPath, ["-e", script]))
        } catch let error as SwitchError {
            throw Self.mapCancellationIfNeeded(error)
        }
    }

    // MARK: - 内部

    /// `pmset -g` の出力から `SleepDisabled` の値を読み取る。行が無ければ無効とみなす。
    static func parseSleepDisabled(from output: String) -> Bool {
        for line in output.split(separator: "\n") where line.contains(sleepDisabledKey) {
            let value = line.split(whereSeparator: \.isWhitespace).last
            return value == "1"
        }
        return false
    }

    /// 認証ダイアログのキャンセルは失敗ではなくユーザーの操作なので、その旨を伝える。
    private static func mapCancellationIfNeeded(_ error: SwitchError) -> SwitchError {
        guard case let .commandFailed(_, _, message) = error,
              userCancelledMarkers.contains(where: message.contains)
        else {
            return error
        }
        return .permissionDenied(reason: "管理者パスワードの入力がキャンセルされました。")
    }
}
