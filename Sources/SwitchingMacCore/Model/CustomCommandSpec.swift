import Foundation

/// カスタムスイッチの状態判定方法。
public enum ShellStateDetection: Codable, Hashable, Sendable {
    /// 状態取得コマンドの終了コードが 0 なら ON とみなす
    case exitCodeZeroMeansOn
    /// 状態取得コマンドの標準出力（前後の空白を除去）が指定文字列と一致すれば ON とみなす
    case outputEquals(String)
    /// 状態取得を行わず、アプリが最後に適用した値を記憶する
    case remembered
}

/// ユーザー定義スイッチのコマンド定義。
///
/// 値は常にユーザー入力に由来するため、利用前に `validate()` を通すこと。
public struct CustomCommandSpec: Codable, Hashable, Sendable {
    /// コマンド文字列の最大長。設定ファイル肥大と誤入力の歯止め。
    public static let maxCommandLength = 2_000

    /// ON にするときに実行するコマンド
    public let onCommand: String
    /// OFF にするときに実行するコマンド
    public let offCommand: String
    /// 現在状態を取得するコマンド（`remembered` の場合は不要）
    public let stateCommand: String
    /// 状態の判定方法
    public let stateDetection: ShellStateDetection

    public init(
        onCommand: String,
        offCommand: String,
        stateCommand: String = "",
        stateDetection: ShellStateDetection = .remembered
    ) {
        self.onCommand = onCommand
        self.offCommand = offCommand
        self.stateCommand = stateCommand
        self.stateDetection = stateDetection
    }

    /// 定義の妥当性を検証する。
    /// - Throws: `SwitchError.invalidDefinition` 検証に失敗した場合
    public func validate() throws {
        try Self.validateCommand(onCommand, label: "ON コマンド", allowEmpty: false)
        try Self.validateCommand(offCommand, label: "OFF コマンド", allowEmpty: false)

        switch stateDetection {
        case .remembered:
            // 状態取得コマンドは使われないため、空でも構わない。
            try Self.validateCommand(stateCommand, label: "状態取得コマンド", allowEmpty: true)
        case .exitCodeZeroMeansOn, .outputEquals:
            try Self.validateCommand(stateCommand, label: "状態取得コマンド", allowEmpty: false)
        }
    }

    private static func validateCommand(
        _ command: String,
        label: String,
        allowEmpty: Bool
    ) throws {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            guard allowEmpty else {
                throw SwitchError.invalidDefinition(reason: "\(label)が入力されていません。")
            }
            return
        }
        guard trimmed.count <= maxCommandLength else {
            throw SwitchError.invalidDefinition(
                reason: "\(label)が長すぎます（最大 \(maxCommandLength) 文字）。"
            )
        }
        guard !trimmed.contains("\0") else {
            throw SwitchError.invalidDefinition(reason: "\(label)に使用できない文字が含まれています。")
        }
    }
}
