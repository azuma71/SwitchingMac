import Foundation

/// 永続化されるユーザー設定の全体。
///
/// 値は不変で、変更操作はすべて新しいインスタンスを返す。
public struct SwitchConfiguration: Codable, Hashable, Sendable {
    /// 設定ファイルの現行スキーマ版。互換性のない変更時に繰り上げる。
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    /// 登録済みスイッチ（組込 + カスタム）
    public let switches: [SwitchDefinition]
    /// 状態取得を行わないスイッチのために記憶した最終値。キーは `SwitchDefinition.id`。
    public let rememberedStates: [String: Bool]

    public init(
        schemaVersion: Int = SwitchConfiguration.currentSchemaVersion,
        switches: [SwitchDefinition],
        rememberedStates: [String: Bool] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.switches = switches
        self.rememberedStates = rememberedStates
    }

    /// 初回起動時の既定設定。
    public static func makeDefault() -> SwitchConfiguration {
        SwitchConfiguration(switches: BuiltinSwitchCatalog.definitions)
    }

    // MARK: - 参照

    /// 並び順に整列した全スイッチ。
    public var orderedSwitches: [SwitchDefinition] {
        switches.sorted { lhs, rhs in
            lhs.sortOrder == rhs.sortOrder
                ? lhs.id < rhs.id
                : lhs.sortOrder < rhs.sortOrder
        }
    }

    /// メニューバーに表示するスイッチ（並び順）。
    public var menuBarSwitches: [SwitchDefinition] {
        orderedSwitches.filter(\.isVisibleInMenuBar)
    }

    public func definition(withID id: String) -> SwitchDefinition? {
        switches.first { $0.id == id }
    }

    public func rememberedState(forID id: String) -> Bool? {
        rememberedStates[id]
    }

    // MARK: - 更新（すべて新しいインスタンスを返す）

    /// スイッチを追加する。ID が重複する場合は既存を置き換える。
    public func adding(_ definition: SwitchDefinition) -> SwitchConfiguration {
        if switches.contains(where: { $0.id == definition.id }) {
            return replacing(definition)
        }
        let appended = switches + [definition.updatingSortOrder(nextSortOrder)]
        return copy(switches: appended)
    }

    /// 同じ ID のスイッチを置き換える。存在しない場合は変更しない。
    public func replacing(_ definition: SwitchDefinition) -> SwitchConfiguration {
        let replaced = switches.map { $0.id == definition.id ? definition : $0 }
        return copy(switches: replaced)
    }

    /// スイッチを削除する。組込プリセットは削除せず、非表示にとどめる。
    public func removing(id: String) -> SwitchConfiguration {
        guard let target = definition(withID: id) else { return self }
        guard target.kind.isUserCreatable else {
            return replacing(target.updatingVisibility(false))
        }
        return copy(
            switches: switches.filter { $0.id != id },
            rememberedStates: rememberedStates.filter { $0.key != id }
        )
    }

    /// 指定された ID 順に並び替える。一覧に含まれない ID は末尾に元の順序で残す。
    public func reordering(idsInOrder: [String]) -> SwitchConfiguration {
        let rank = Dictionary(
            uniqueKeysWithValues: idsInOrder.enumerated().map { ($0.element, $0.offset) }
        )
        let reordered = orderedSwitches.enumerated().map { index, definition in
            definition.updatingSortOrder(rank[definition.id] ?? idsInOrder.count + index)
        }
        return copy(switches: reordered)
    }

    /// 状態を記憶する方式のスイッチの最終値を更新する。
    public func updatingRememberedState(_ isOn: Bool, forID id: String) -> SwitchConfiguration {
        var updated = rememberedStates
        updated[id] = isOn
        return copy(rememberedStates: updated)
    }

    /// 設定ファイルに存在しない組込スイッチを既定値で補う。
    ///
    /// アプリ更新で組込スイッチが追加された場合に、既存ユーザーの設定へ反映するために使う。
    public func mergingMissingBuiltins() -> SwitchConfiguration {
        let existingIDs = Set(switches.map(\.id))
        let missing = BuiltinSwitchCatalog.definitions
            .filter { !existingIDs.contains($0.id) }
        guard !missing.isEmpty else { return self }

        let appended = missing.enumerated().map { index, definition in
            definition.updatingSortOrder(nextSortOrder + index)
        }
        return copy(switches: switches + appended)
    }

    // MARK: - 内部

    private var nextSortOrder: Int {
        (switches.map(\.sortOrder).max() ?? -1) + 1
    }

    private func copy(
        switches: [SwitchDefinition]? = nil,
        rememberedStates: [String: Bool]? = nil
    ) -> SwitchConfiguration {
        SwitchConfiguration(
            schemaVersion: schemaVersion,
            switches: switches ?? self.switches,
            rememberedStates: rememberedStates ?? self.rememberedStates
        )
    }
}
