import Foundation

/// ユーザーが定義したシェルコマンドで ON / OFF するスイッチ。
///
/// 実行されるのはユーザー自身が設定画面で入力したコマンドのみで、
/// アプリ側が外部入力をコマンド文字列へ連結することはない。
public struct ShellSwitchProvider: SwitchProvider {
    private let runner: any CommandRunning

    public init(runner: any CommandRunning) {
        self.runner = runner
    }

    public var kind: SwitchKind { .custom }

    public var availability: ProviderAvailability {
        .requiresFullAccess(reason: "任意のコマンド実行はサンドボックスおよび App Store の規約で認められていません。")
    }

    public func readState(_ context: SwitchContext) async -> SwitchState {
        guard let spec = context.definition.customCommand else {
            return .unavailable(reason: "コマンドが設定されていません。")
        }

        switch spec.stateDetection {
        case .remembered:
            guard let remembered = context.rememberedState else { return .unknown }
            return .from(isOn: remembered)

        case .exitCodeZeroMeansOn:
            guard let result = try? await runner.run(.shell(spec.stateCommand)) else {
                return .unknown
            }
            return .from(isOn: result.isSuccess)

        case let .outputEquals(expected):
            guard let result = try? await runner.run(.shell(spec.stateCommand)) else {
                return .unknown
            }
            guard result.isSuccess else { return .unknown }
            return .from(isOn: result.trimmedOutput == expected.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    public func apply(isOn: Bool, context: SwitchContext) async throws {
        guard let spec = context.definition.customCommand else {
            throw SwitchError.invalidDefinition(reason: "コマンドが設定されていません。")
        }
        try spec.validate()

        let script = isOn ? spec.onCommand : spec.offCommand
        try await runner.runExpectingSuccess(.shell(script))
    }
}
