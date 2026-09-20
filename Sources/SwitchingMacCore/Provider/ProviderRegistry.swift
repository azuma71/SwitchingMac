import Foundation

/// 種別から `SwitchProvider` を引くレジストリ。
///
/// 登録内容を差し替えることで、サンドボックス版ビルドや
/// テスト用のフェイク実装へ切り替えられる。
public struct ProviderRegistry: Sendable {
    private let providersByKind: [SwitchKind: any SwitchProvider]

    public init(providers: [any SwitchProvider]) {
        providersByKind = Dictionary(
            providers.map { ($0.kind, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
    }

    public func provider(for kind: SwitchKind) -> (any SwitchProvider)? {
        providersByKind[kind]
    }

    public func isSupported(_ kind: SwitchKind) -> Bool {
        providersByKind[kind] != nil
    }

    /// 登録済みの種別（`SwitchKind.allCases` の順）。
    public var supportedKinds: [SwitchKind] {
        SwitchKind.allCases.filter { providersByKind[$0] != nil }
    }

    /// サンドボックス下で動作する機能だけに絞った新しいレジストリを返す。
    public func filteringSandboxSafeOnly() -> ProviderRegistry {
        ProviderRegistry(
            providers: providersByKind.values.filter { $0.availability.isSandboxSafe }
        )
    }
}
