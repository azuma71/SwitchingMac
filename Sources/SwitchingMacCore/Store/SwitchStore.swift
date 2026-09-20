import Foundation
import Observation

/// この版で利用できない機能に表示する理由
private let unsupportedFeatureReason = "この版のアプリでは利用できません。"

/// 画面が参照するアプリ状態。設定の保持、状態取得、スイッチ操作を仲介する。
@MainActor
@Observable
public final class SwitchStore {
    /// 現在の設定
    public private(set) var configuration: SwitchConfiguration
    /// スイッチ ID ごとの現在状態
    public private(set) var states: [String: SwitchState] = [:]
    /// 適用処理の実行中である ID
    public private(set) var busyIDs: Set<String> = []
    /// 直近のエラー。表示後は `dismissError()` で消す。
    public private(set) var errorMessage: String?

    private let registry: ProviderRegistry
    private let store: any ConfigurationStoring

    public init(registry: ProviderRegistry, store: any ConfigurationStoring) {
        self.registry = registry
        self.store = store
        configuration = .makeDefault()
        loadConfiguration()
    }

    // MARK: - 参照

    public func state(forID id: String) -> SwitchState {
        states[id] ?? .unknown
    }

    public func isBusy(id: String) -> Bool {
        busyIDs.contains(id)
    }

    /// 設定画面で編集できるスイッチ一覧（並び順）
    public var orderedSwitches: [SwitchDefinition] {
        configuration.orderedSwitches
    }

    /// メニューバーに表示するスイッチ一覧（並び順）
    public var menuBarSwitches: [SwitchDefinition] {
        configuration.menuBarSwitches
    }

    public func dismissError() {
        errorMessage = nil
    }

    // MARK: - 読み込み

    /// 設定を読み込む。破損していた場合は退避したうえで既定設定に戻す。
    public func loadConfiguration() {
        do {
            configuration = try store.load()
        } catch {
            configuration = .makeDefault()
            errorMessage = recoverFromLoadFailure(error)
        }
    }

    private func recoverFromLoadFailure(_ error: any Error) -> String {
        let base = error.localizedDescription
        do {
            if let quarantined = try store.quarantineCorruptedFile() {
                return base + "\n設定を初期化しました。元のファイルは "
                    + "\(quarantined.lastPathComponent) として保存しています。"
            }
            return base + "\n設定を初期化しました。"
        } catch {
            return base + "\n設定の退避にも失敗しました: \(error.localizedDescription)"
        }
    }

    // MARK: - 状態取得

    /// すべてのスイッチの状態を取得し直す。
    public func refreshStates() async {
        let contexts = configuration.switches.map(makeContext(for:))
        let registry = registry

        let fetched = await withTaskGroup(of: (String, SwitchState).self) { group in
            for context in contexts {
                let id = context.definition.id
                guard let provider = registry.provider(for: context.definition.kind) else {
                    group.addTask { (id, .unavailable(reason: unsupportedFeatureReason)) }
                    continue
                }
                group.addTask { (id, await provider.readState(context)) }
            }

            var results: [String: SwitchState] = [:]
            for await (id, state) in group {
                results[id] = state
            }
            return results
        }

        states = fetched
    }

    /// 単一スイッチの状態を取得し直す。
    public func refreshState(forID id: String) async {
        guard let definition = configuration.definition(withID: id) else { return }
        states[id] = await currentState(of: definition)
    }

    // MARK: - 操作

    /// 現在状態を反転させる。状態が不明な場合は ON を試みる。
    public func toggle(id: String) async {
        let desired = !state(forID: id).isOn
        await setState(desired, forID: id)
    }

    /// 指定した状態を適用する。
    public func setState(_ isOn: Bool, forID id: String) async {
        guard let definition = configuration.definition(withID: id) else { return }
        guard let provider = registry.provider(for: definition.kind) else {
            states[id] = .unavailable(reason: unsupportedFeatureReason)
            return
        }

        busyIDs.insert(id)
        defer { busyIDs.remove(id) }

        do {
            try await provider.apply(isOn: isOn, context: makeContext(for: definition))
            if usesRememberedState(definition) {
                persist(configuration.updatingRememberedState(isOn, forID: id))
            }
        } catch {
            errorMessage = "「\(definition.title)」を切り替えられませんでした。\n"
                + error.localizedDescription
        }

        states[id] = await currentState(of: definition)
    }

    // MARK: - 設定の編集

    /// カスタムスイッチを追加する。
    /// - Throws: `SwitchError.invalidDefinition` 定義が不正な場合
    public func addSwitch(_ definition: SwitchDefinition) throws {
        try definition.validate()
        persist(configuration.adding(definition))
    }

    /// 既存スイッチの定義を更新する。
    /// - Throws: `SwitchError.invalidDefinition` 定義が不正な場合
    public func updateSwitch(_ definition: SwitchDefinition) throws {
        try definition.validate()
        persist(configuration.replacing(definition))
    }

    /// スイッチを削除する。組込スイッチは非表示になるだけで一覧からは消えない。
    public func removeSwitch(id: String) {
        persist(configuration.removing(id: id))
        states.removeValue(forKey: id)
    }

    /// メニューバーへの表示 / 非表示を切り替える。
    public func setVisibility(_ isVisible: Bool, forID id: String) {
        guard let definition = configuration.definition(withID: id) else { return }
        persist(configuration.replacing(definition.updatingVisibility(isVisible)))
    }

    /// 一覧の並び替え（SwiftUI の `onMove` 用）。
    public func moveSwitches(fromOffsets source: IndexSet, toOffset destination: Int) {
        let ids = orderedSwitches
            .map(\.id)
            .movingElements(fromOffsets: source, toOffset: destination)
        persist(configuration.reordering(idsInOrder: ids))
    }

    // MARK: - 内部

    private func currentState(of definition: SwitchDefinition) async -> SwitchState {
        guard let provider = registry.provider(for: definition.kind) else {
            return .unavailable(reason: unsupportedFeatureReason)
        }
        return await provider.readState(makeContext(for: definition))
    }

    private func makeContext(for definition: SwitchDefinition) -> SwitchContext {
        SwitchContext(
            definition: definition,
            rememberedState: configuration.rememberedState(forID: definition.id)
        )
    }

    private func usesRememberedState(_ definition: SwitchDefinition) -> Bool {
        definition.customCommand?.stateDetection == .remembered
    }

    private func persist(_ newConfiguration: SwitchConfiguration) {
        configuration = newConfiguration
        do {
            try store.save(newConfiguration)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
