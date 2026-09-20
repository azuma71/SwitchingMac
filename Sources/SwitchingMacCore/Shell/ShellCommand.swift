import Foundation

/// 実行する外部コマンド。
///
/// 引数は実行ファイルへ直接渡す。組込スイッチではシェル文字列を組み立てないため、
/// 引数経由でのコマンド注入は発生しない。
public struct ShellCommand: Sendable, Hashable {
    /// カスタムスイッチのスクリプト実行に使うシェル
    public static let defaultShellPath = "/bin/zsh"
    /// シェルに渡すオプション（ログインシェルとして PATH を解決させる）
    public static let defaultShellArguments = ["-lc"]

    public let executable: String
    public let arguments: [String]

    public init(executable: String, arguments: [String] = []) {
        self.executable = executable
        self.arguments = arguments
    }

    /// 実行ファイルと引数を直接指定する。
    public static func tool(_ executable: String, _ arguments: [String] = []) -> ShellCommand {
        ShellCommand(executable: executable, arguments: arguments)
    }

    /// 任意のスクリプトをシェル経由で実行する。ユーザー定義スイッチ専用。
    public static func shell(_ script: String) -> ShellCommand {
        ShellCommand(
            executable: defaultShellPath,
            arguments: defaultShellArguments + [script]
        )
    }

    /// エラーメッセージなどに表示する文字列。
    public var displayString: String {
        ([executable] + arguments).joined(separator: " ")
    }
}

/// コマンドの実行結果。
public struct CommandResult: Sendable, Hashable {
    public let exitCode: Int32
    public let standardOutput: String
    public let standardError: String

    public init(exitCode: Int32, standardOutput: String = "", standardError: String = "") {
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
    }

    public var isSuccess: Bool { exitCode == 0 }

    /// 前後の空白・改行を取り除いた標準出力。
    public var trimmedOutput: String {
        standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// コマンド実行の抽象。テストではフェイク実装に差し替える。
public protocol CommandRunning: Sendable {
    /// コマンドを実行して結果を返す。
    /// - Throws: `SwitchError.commandNotExecutable` 起動自体に失敗した場合
    func run(_ command: ShellCommand) async throws -> CommandResult
}

public extension CommandRunning {
    /// 実行し、終了コードが 0 でなければエラーを投げる。
    @discardableResult
    func runExpectingSuccess(_ command: ShellCommand) async throws -> CommandResult {
        let result = try await run(command)
        guard result.isSuccess else {
            throw SwitchError.commandFailed(
                command: command.displayString,
                exitCode: result.exitCode,
                message: result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return result
    }
}
