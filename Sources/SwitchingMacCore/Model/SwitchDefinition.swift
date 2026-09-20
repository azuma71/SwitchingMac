import Foundation

/// メニューバーに並ぶスイッチ 1 個分の定義。
///
/// 値は不変。変更は `updating...` が返す新しいインスタンスで行う。
public struct SwitchDefinition: Identifiable, Codable, Hashable, Sendable {
    /// タイトルの最大長
    public static let maxTitleLength = 60

    /// 組込プリセットは種別名、カスタムは生成時の一意な文字列。
    public let id: String
    public let kind: SwitchKind
    /// メニューに表示する名称
    public let title: String
    /// メニューに表示する SF Symbols 名
    public let symbolName: String
    /// メニューバーに表示するか（設定画面には常に表示される）
    public let isVisibleInMenuBar: Bool
    /// メニュー内の並び順。小さいほど上。
    public let sortOrder: Int
    /// `kind == .custom` のときのみ保持するコマンド定義
    public let customCommand: CustomCommandSpec?

    public init(
        id: String,
        kind: SwitchKind,
        title: String,
        symbolName: String,
        isVisibleInMenuBar: Bool = true,
        sortOrder: Int = 0,
        customCommand: CustomCommandSpec? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.symbolName = symbolName
        self.isVisibleInMenuBar = isVisibleInMenuBar
        self.sortOrder = sortOrder
        self.customCommand = customCommand
    }

    /// 組込プリセットの定義を生成する。
    public static func builtin(
        kind: SwitchKind,
        title: String,
        symbolName: String,
        sortOrder: Int
    ) -> SwitchDefinition {
        SwitchDefinition(
            id: kind.rawValue,
            kind: kind,
            title: title,
            symbolName: symbolName,
            sortOrder: sortOrder
        )
    }

    /// カスタムスイッチの定義を生成する。
    /// - Parameter identifier: 明示しない場合は新しい一意な値を採番する。
    public static func custom(
        identifier: String = "custom-\(UUID().uuidString)",
        title: String,
        symbolName: String = "terminal",
        sortOrder: Int = 0,
        command: CustomCommandSpec
    ) -> SwitchDefinition {
        SwitchDefinition(
            id: identifier,
            kind: .custom,
            title: title,
            symbolName: symbolName,
            sortOrder: sortOrder,
            customCommand: command
        )
    }

    /// 定義の妥当性を検証する。
    /// - Throws: `SwitchError.invalidDefinition` 検証に失敗した場合
    public func validate() throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw SwitchError.invalidDefinition(reason: "名称が入力されていません。")
        }
        guard trimmedTitle.count <= Self.maxTitleLength else {
            throw SwitchError.invalidDefinition(
                reason: "名称が長すぎます（最大 \(Self.maxTitleLength) 文字）。"
            )
        }
        guard !symbolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SwitchError.invalidDefinition(reason: "アイコンが指定されていません。")
        }

        if kind == .custom {
            guard let customCommand else {
                throw SwitchError.invalidDefinition(reason: "カスタムスイッチにコマンドが設定されていません。")
            }
            try customCommand.validate()
        }
    }

    public func updatingTitle(_ newTitle: String) -> SwitchDefinition {
        copy(title: newTitle)
    }

    public func updatingSymbolName(_ newSymbolName: String) -> SwitchDefinition {
        copy(symbolName: newSymbolName)
    }

    public func updatingVisibility(_ isVisible: Bool) -> SwitchDefinition {
        copy(isVisibleInMenuBar: isVisible)
    }

    public func updatingSortOrder(_ newSortOrder: Int) -> SwitchDefinition {
        copy(sortOrder: newSortOrder)
    }

    public func updatingCustomCommand(_ newCommand: CustomCommandSpec?) -> SwitchDefinition {
        SwitchDefinition(
            id: id,
            kind: kind,
            title: title,
            symbolName: symbolName,
            isVisibleInMenuBar: isVisibleInMenuBar,
            sortOrder: sortOrder,
            customCommand: newCommand
        )
    }

    private func copy(
        title: String? = nil,
        symbolName: String? = nil,
        isVisibleInMenuBar: Bool? = nil,
        sortOrder: Int? = nil
    ) -> SwitchDefinition {
        SwitchDefinition(
            id: id,
            kind: kind,
            title: title ?? self.title,
            symbolName: symbolName ?? self.symbolName,
            isVisibleInMenuBar: isVisibleInMenuBar ?? self.isVisibleInMenuBar,
            sortOrder: sortOrder ?? self.sortOrder,
            customCommand: customCommand
        )
    }
}
