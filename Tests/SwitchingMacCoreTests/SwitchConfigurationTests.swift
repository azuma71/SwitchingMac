import Foundation
import Testing
@testable import SwitchingMacCore

@Suite("設定モデル")
struct SwitchConfigurationTests {
    @Test("既定設定には組込スイッチがすべて含まれる")
    func defaultContainsAllBuiltins() {
        let configuration = SwitchConfiguration.makeDefault()

        #expect(configuration.switches.count == BuiltinSwitchCatalog.definitions.count)
        for kind in SwitchKind.allCases where kind != .custom {
            #expect(configuration.switches.contains { $0.kind == kind })
        }
    }

    @Test("orderedSwitches は sortOrder の昇順で返る")
    func orderedBySortOrder() {
        let configuration = SwitchConfiguration(switches: [
            .builtin(kind: .wifi, title: "C", symbolName: "wifi", sortOrder: 2),
            .builtin(kind: .darkMode, title: "A", symbolName: "moon", sortOrder: 0),
            .builtin(kind: .preventSleep, title: "B", symbolName: "cup", sortOrder: 1),
        ])

        #expect(configuration.orderedSwitches.map(\.title) == ["A", "B", "C"])
    }

    @Test("menuBarSwitches は非表示のスイッチを除外する")
    func menuBarSwitchesExcludeHidden() {
        let hidden = SwitchDefinition
            .builtin(kind: .wifi, title: "Wi-Fi", symbolName: "wifi", sortOrder: 1)
            .updatingVisibility(false)
        let configuration = SwitchConfiguration(switches: [
            .builtin(kind: .darkMode, title: "ダーク", symbolName: "moon", sortOrder: 0),
            hidden,
        ])

        #expect(configuration.menuBarSwitches.map(\.kind) == [.darkMode])
    }

    @Test("カスタムスイッチを追加すると末尾の並び順が割り当てられる")
    func addingAssignsNextSortOrder() {
        let configuration = SwitchConfiguration.makeDefault()
        let maxOrder = configuration.switches.map(\.sortOrder).max() ?? 0

        let updated = configuration.adding(TestFixtures.customDefinition())
        let added = updated.definition(withID: "custom-test")

        #expect(updated.switches.count == configuration.switches.count + 1)
        #expect(added?.sortOrder == maxOrder + 1)
    }

    @Test("同じ ID を追加すると置き換えになる")
    func addingSameIDReplaces() {
        let original = TestFixtures.customDefinition(title: "元の名前")
        let configuration = SwitchConfiguration.makeDefault().adding(original)

        let updated = configuration.adding(original.updatingTitle("新しい名前"))

        #expect(updated.switches.filter { $0.id == "custom-test" }.count == 1)
        #expect(updated.definition(withID: "custom-test")?.title == "新しい名前")
    }

    @Test("カスタムスイッチは削除され、記憶した状態も消える")
    func removingCustomSwitch() {
        let configuration = SwitchConfiguration.makeDefault()
            .adding(TestFixtures.customDefinition())
            .updatingRememberedState(true, forID: "custom-test")

        let updated = configuration.removing(id: "custom-test")

        #expect(updated.definition(withID: "custom-test") == nil)
        #expect(updated.rememberedState(forID: "custom-test") == nil)
    }

    @Test("組込スイッチは削除されず非表示になる")
    func removingBuiltinHidesInstead() {
        let configuration = SwitchConfiguration.makeDefault()

        let updated = configuration.removing(id: SwitchKind.wifi.rawValue)
        let wifi = updated.definition(withID: SwitchKind.wifi.rawValue)

        #expect(updated.switches.count == configuration.switches.count)
        #expect(wifi?.isVisibleInMenuBar == false)
    }

    @Test("指定した ID 順に並び替えられる")
    func reordering() {
        let configuration = SwitchConfiguration.makeDefault()
        let reversed = configuration.orderedSwitches.map(\.id).reversed().map { $0 }

        let updated = configuration.reordering(idsInOrder: reversed)

        #expect(updated.orderedSwitches.map(\.id) == reversed)
    }

    @Test("設定に無い組込スイッチが補完される")
    func mergingMissingBuiltins() {
        let partial = SwitchConfiguration(switches: [
            .builtin(kind: .darkMode, title: "ダーク", symbolName: "moon", sortOrder: 0),
        ])

        let merged = partial.mergingMissingBuiltins()

        #expect(merged.switches.count == BuiltinSwitchCatalog.definitions.count)
        #expect(merged.definition(withID: SwitchKind.wifi.rawValue) != nil)
    }

    @Test("記憶した状態を保存・取得できる")
    func rememberedState() {
        let configuration = SwitchConfiguration.makeDefault()
            .updatingRememberedState(true, forID: "custom-a")
            .updatingRememberedState(false, forID: "custom-b")

        #expect(configuration.rememberedState(forID: "custom-a") == true)
        #expect(configuration.rememberedState(forID: "custom-b") == false)
        #expect(configuration.rememberedState(forID: "custom-c") == nil)
    }

    @Test("JSON へエンコードして復元できる")
    func codableRoundTrip() throws {
        let original = SwitchConfiguration.makeDefault()
            .adding(TestFixtures.customDefinition(detection: .outputEquals("connected")))
            .updatingRememberedState(true, forID: "custom-test")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SwitchConfiguration.self, from: data)

        #expect(decoded == original)
    }
}
