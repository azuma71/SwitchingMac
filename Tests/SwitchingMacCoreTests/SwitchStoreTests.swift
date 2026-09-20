import Foundation
import Testing
@testable import SwitchingMacCore

@MainActor
@Suite("アプリ状態ストア")
struct SwitchStoreTests {
    /// 指定したプロバイダと設定でストアを組み立てる。
    private func makeStore(
        providers: [any SwitchProvider],
        switches: [SwitchDefinition],
        backing: InMemoryConfigurationStore? = nil
    ) -> (store: SwitchStore, backing: InMemoryConfigurationStore) {
        let backingStore = backing ?? InMemoryConfigurationStore(
            initial: SwitchConfiguration(switches: switches)
        )
        let store = SwitchStore(
            registry: ProviderRegistry(providers: providers),
            store: backingStore
        )
        return (store, backingStore)
    }

    private var wifiDefinition: SwitchDefinition {
        BuiltinSwitchCatalog.definition(for: .wifi)!
    }

    // MARK: - 読み込み

    @Test("保存済みの設定を読み込む")
    func loadsStoredConfiguration() {
        let (store, _) = makeStore(
            providers: [FakeSwitchProvider(kind: .wifi)],
            switches: [wifiDefinition]
        )

        #expect(store.orderedSwitches.map(\.id) == [wifiDefinition.id])
        #expect(store.errorMessage == nil)
    }

    @Test("読み込みに失敗したら退避して既定設定に戻す")
    func recoversFromLoadFailure() {
        let backing = InMemoryConfigurationStore(
            loadError: ConfigurationStoreError.decodingFailed(path: "/tmp/x", underlying: "壊れています")
        )
        let (store, _) = makeStore(providers: [], switches: [], backing: backing)

        #expect(store.orderedSwitches.count == BuiltinSwitchCatalog.definitions.count)
        #expect(backing.quarantineCallCount == 1)
        #expect(store.errorMessage != nil)
    }

    // MARK: - 状態取得

    @Test("全スイッチの状態を取得する")
    func refreshStates() async {
        let (store, _) = makeStore(
            providers: [
                FakeSwitchProvider(kind: .wifi, state: .on),
                FakeSwitchProvider(kind: .darkMode, state: .off),
            ],
            switches: [wifiDefinition, BuiltinSwitchCatalog.definition(for: .darkMode)!]
        )

        await store.refreshStates()

        #expect(store.state(forID: SwitchKind.wifi.rawValue) == .on)
        #expect(store.state(forID: SwitchKind.darkMode.rawValue) == .off)
    }

    @Test("対応プロバイダが無い種別は利用不可になる")
    func unsupportedKindIsUnavailable() async {
        let (store, _) = makeStore(providers: [], switches: [wifiDefinition])

        await store.refreshStates()

        #expect(store.state(forID: wifiDefinition.id).isOperable == false)
    }

    // MARK: - 操作

    @Test("状態を適用するとプロバイダが呼ばれ、表示状態も更新される")
    func setStateAppliesAndRefreshes() async {
        let provider = FakeSwitchProvider(kind: .wifi, state: .off)
        let (store, _) = makeStore(providers: [provider], switches: [wifiDefinition])

        await store.setState(true, forID: wifiDefinition.id)

        #expect(provider.recordedApplications == [true])
        #expect(store.state(forID: wifiDefinition.id) == .on)
        #expect(store.isBusy(id: wifiDefinition.id) == false)
    }

    @Test("toggle は現在状態を反転させる")
    func toggleInvertsState() async {
        let provider = FakeSwitchProvider(kind: .wifi, state: .on)
        let (store, _) = makeStore(providers: [provider], switches: [wifiDefinition])
        await store.refreshStates()

        await store.toggle(id: wifiDefinition.id)

        #expect(provider.recordedApplications == [false])
        #expect(store.state(forID: wifiDefinition.id) == .off)
    }

    @Test("適用に失敗したらエラーメッセージを表示する")
    func applyFailureSetsErrorMessage() async {
        let provider = FakeSwitchProvider(
            kind: .wifi,
            applyError: .permissionDenied(reason: "許可がありません")
        )
        let (store, _) = makeStore(providers: [provider], switches: [wifiDefinition])

        await store.setState(true, forID: wifiDefinition.id)

        #expect(store.errorMessage?.contains("Wi-Fi") == true)
        #expect(provider.recordedApplications.isEmpty)

        store.dismissError()
        #expect(store.errorMessage == nil)
    }

    @Test("状態を記憶する方式のスイッチは適用結果が保存される")
    func rememberedStateIsPersisted() async {
        let definition = TestFixtures.customDefinition(detection: .remembered)
        let (store, backing) = makeStore(
            providers: [FakeSwitchProvider(kind: .custom)],
            switches: [definition]
        )

        await store.setState(true, forID: definition.id)

        #expect(store.configuration.rememberedState(forID: definition.id) == true)
        #expect(backing.savedConfiguration?.rememberedState(forID: definition.id) == true)
    }

    // MARK: - 設定の編集

    @Test("カスタムスイッチを追加すると保存される")
    func addSwitchPersists() throws {
        let (store, backing) = makeStore(providers: [], switches: [wifiDefinition])

        try store.addSwitch(TestFixtures.customDefinition())

        #expect(store.orderedSwitches.count == 2)
        #expect(backing.savedConfiguration?.definition(withID: "custom-test") != nil)
    }

    @Test("不正なカスタムスイッチは追加できない")
    func addInvalidSwitchThrows() {
        let (store, _) = makeStore(providers: [], switches: [])

        #expect(throws: SwitchError.self) {
            try store.addSwitch(TestFixtures.customDefinition(title: ""))
        }
        #expect(store.orderedSwitches.isEmpty)
    }

    @Test("カスタムスイッチを更新できる")
    func updateSwitch() throws {
        let definition = TestFixtures.customDefinition(title: "元の名前")
        let (store, _) = makeStore(providers: [], switches: [definition])

        try store.updateSwitch(definition.updatingTitle("新しい名前"))

        #expect(store.orderedSwitches.first?.title == "新しい名前")
    }

    @Test("カスタムスイッチを削除すると状態も破棄される")
    func removeSwitchDropsState() async {
        let definition = TestFixtures.customDefinition()
        let (store, _) = makeStore(
            providers: [FakeSwitchProvider(kind: .custom, state: .on)],
            switches: [definition]
        )
        await store.refreshStates()

        store.removeSwitch(id: definition.id)

        #expect(store.orderedSwitches.isEmpty)
        #expect(store.state(forID: definition.id) == .unknown)
    }

    @Test("メニューバーへの表示を切り替えられる")
    func setVisibility() {
        let (store, backing) = makeStore(providers: [], switches: [wifiDefinition])

        store.setVisibility(false, forID: wifiDefinition.id)

        #expect(store.menuBarSwitches.isEmpty)
        #expect(backing.savedConfiguration?.definition(withID: wifiDefinition.id)?.isVisibleInMenuBar == false)
    }

    @Test("並び替えると順序が保存される")
    func moveSwitches() {
        let first = BuiltinSwitchCatalog.definition(for: .darkMode)!
        let second = BuiltinSwitchCatalog.definition(for: .wifi)!
        let (store, backing) = makeStore(providers: [], switches: [first, second])

        store.moveSwitches(fromOffsets: IndexSet(integer: 1), toOffset: 0)

        #expect(store.orderedSwitches.map(\.id) == [second.id, first.id])
        #expect(backing.savedConfiguration?.orderedSwitches.map(\.id) == [second.id, first.id])
    }

    @Test("保存に失敗したらエラーメッセージを表示する")
    func persistFailureSetsErrorMessage() throws {
        let backing = InMemoryConfigurationStore(
            initial: SwitchConfiguration(switches: [wifiDefinition]),
            saveError: ConfigurationStoreError.unwritable(path: "/tmp/x", underlying: "書き込めません")
        )
        let (store, _) = makeStore(providers: [], switches: [], backing: backing)

        try store.addSwitch(TestFixtures.customDefinition())

        #expect(store.errorMessage != nil)
    }
}
