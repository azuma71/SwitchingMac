import Foundation

/// スイッチを実際に操作する際に渡す文脈。
public struct SwitchContext: Sendable, Hashable {
    public let definition: SwitchDefinition
    /// 状態取得を行わない方式のために保存してある最終値
    public let rememberedState: Bool?

    public init(definition: SwitchDefinition, rememberedState: Bool? = nil) {
        self.definition = definition
        self.rememberedState = rememberedState
    }
}

/// 機能がサンドボックス環境で動作するかどうか。
///
/// App Store 版（サンドボックス必須）のビルドでは `sandboxSafe` のみを登録する。
public enum ProviderAvailability: Sendable, Hashable {
    /// サンドボックス内でも動作する
    case sandboxSafe
    /// サンドボックス外でのみ動作する（理由は UI に表示する）
    case requiresFullAccess(reason: String)

    public var isSandboxSafe: Bool {
        self == .sandboxSafe
    }
}

/// 1 種別のスイッチに対する読み取り・適用の実装。
public protocol SwitchProvider: Sendable {
    /// 担当する機能種別
    var kind: SwitchKind { get }
    /// サンドボックス下で利用できるか
    var availability: ProviderAvailability { get }

    /// 現在の状態を取得する。取得できない場合は `.unknown` を返し、例外は投げない。
    func readState(_ context: SwitchContext) async -> SwitchState

    /// 状態を適用する。
    /// - Throws: `SwitchError` 適用に失敗した場合
    func apply(isOn: Bool, context: SwitchContext) async throws
}
