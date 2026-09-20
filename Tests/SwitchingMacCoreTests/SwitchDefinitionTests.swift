import Foundation
import Testing
@testable import SwitchingMacCore

@Suite("スイッチ定義の検証")
struct SwitchDefinitionTests {
    @Test("組込スイッチの ID は種別名になる")
    func builtinIdentifier() {
        let definition = SwitchDefinition.builtin(
            kind: .wifi, title: "Wi-Fi", symbolName: "wifi", sortOrder: 0
        )

        #expect(definition.id == SwitchKind.wifi.rawValue)
        #expect(definition.kind.isUserCreatable == false)
    }

    @Test("カスタムスイッチの ID は一意に採番される")
    func customIdentifierIsUnique() {
        let first = TestFixtures.customDefinition(id: "custom-\(UUID().uuidString)")
        let second = TestFixtures.customDefinition(id: "custom-\(UUID().uuidString)")

        #expect(first.id != second.id)
    }

    @Test("名称が空の定義は不正")
    func emptyTitleIsInvalid() {
        let definition = TestFixtures.customDefinition(title: "   ")

        #expect(throws: SwitchError.self) { try definition.validate() }
    }

    @Test("名称が長すぎる定義は不正")
    func tooLongTitleIsInvalid() {
        let definition = TestFixtures.customDefinition(
            title: String(repeating: "あ", count: SwitchDefinition.maxTitleLength + 1)
        )

        #expect(throws: SwitchError.self) { try definition.validate() }
    }

    @Test("コマンド未設定のカスタムスイッチは不正")
    func customWithoutCommandIsInvalid() {
        let definition = TestFixtures.customDefinition().updatingCustomCommand(nil)

        #expect(throws: SwitchError.self) { try definition.validate() }
    }

    @Test("妥当な定義は検証を通過する")
    func validDefinitionPasses() throws {
        try TestFixtures.customDefinition().validate()
        try SwitchDefinition
            .builtin(kind: .darkMode, title: "ダーク", symbolName: "moon.fill", sortOrder: 0)
            .validate()
    }

    @Test("updating 系は元の値を変更せず新しい値を返す")
    func updatingReturnsNewInstance() {
        let original = TestFixtures.customDefinition(title: "元")

        let renamed = original.updatingTitle("新")

        #expect(original.title == "元")
        #expect(renamed.title == "新")
        #expect(renamed.id == original.id)
    }
}
