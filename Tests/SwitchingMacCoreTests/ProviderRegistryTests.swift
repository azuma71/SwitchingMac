import Foundation
import Testing
@testable import SwitchingMacCore

@Suite("プロバイダレジストリ")
struct ProviderRegistryTests {
    @Test("既定のレジストリは全種別をカバーする")
    func defaultRegistryCoversAllKinds() {
        let registry = ProviderRegistry.makeDefault(runner: FakeCommandRunner())

        #expect(registry.supportedKinds.count == SwitchKind.allCases.count)
        for kind in SwitchKind.allCases {
            #expect(registry.isSupported(kind))
        }
    }

    @Test("サンドボックス用レジストリは対応機能だけを残す")
    func sandboxSafeRegistryFilters() {
        let registry = ProviderRegistry.makeSandboxSafe(runner: FakeCommandRunner())

        #expect(registry.supportedKinds == [.preventSleep])
        #expect(registry.isSupported(.custom) == false)
        #expect(registry.isSupported(.wifi) == false)
    }

    @Test("同じ種別を登録した場合は後勝ちになる")
    func lastProviderWins() {
        let first = FakeSwitchProvider(kind: .wifi, state: .off)
        let second = FakeSwitchProvider(kind: .wifi, state: .on)
        let registry = ProviderRegistry(providers: [first, second])

        #expect((registry.provider(for: .wifi) as? FakeSwitchProvider) === second)
    }

    @Test("未登録の種別には nil を返す")
    func unregisteredKindReturnsNil() {
        let registry = ProviderRegistry(providers: [FakeSwitchProvider(kind: .wifi)])

        #expect(registry.provider(for: .darkMode) == nil)
    }
}
