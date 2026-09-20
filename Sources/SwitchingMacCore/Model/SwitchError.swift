import Foundation

/// スイッチの読み取り・適用時に発生するエラー。
///
/// `errorDescription` はそのまま UI に表示するため、技術的詳細ではなく
/// ユーザーが次に取るべき行動が分かる文面にする。
public enum SwitchError: LocalizedError, Sendable, Hashable {
    /// コマンドが 0 以外の終了コードを返した
    case commandFailed(command: String, exitCode: Int32, message: String)
    /// コマンドを起動できなかった
    case commandNotExecutable(command: String, reason: String)
    /// この環境では機能が利用できない
    case unavailable(reason: String)
    /// カスタムスイッチの定義が不正
    case invalidDefinition(reason: String)
    /// OS から操作を拒否された（権限不足など）
    case permissionDenied(reason: String)

    public var errorDescription: String? {
        switch self {
        case let .commandFailed(command, exitCode, message):
            let detail = message.isEmpty ? "" : "\n\(message)"
            return "コマンドの実行に失敗しました（終了コード \(exitCode)）: \(command)\(detail)"
        case let .commandNotExecutable(command, reason):
            return "コマンドを起動できませんでした: \(command)\n\(reason)"
        case let .unavailable(reason):
            return "この Mac では利用できません: \(reason)"
        case let .invalidDefinition(reason):
            return "スイッチの設定が不正です: \(reason)"
        case let .permissionDenied(reason):
            return "操作が許可されていません: \(reason)"
        }
    }
}
