import Foundation
import Testing
@testable import SwitchingMacCore

@Suite("カスタム（シェル）スイッチ")
struct ShellSwitchProviderTests {
    @Test("記憶方式では保存済みの値を返す")
    func rememberedStateIsUsed() async {
        let provider = ShellSwitchProvider(runner: FakeCommandRunner())
        let context = SwitchContext(
            definition: TestFixtures.customDefinition(detection: .remembered),
            rememberedState: true
        )

        #expect(await provider.readState(context) == .on)
    }

    @Test("記憶方式で保存値が無ければ不明を返す")
    func rememberedStateMissing() async {
        let provider = ShellSwitchProvider(runner: FakeCommandRunner())
        let context = SwitchContext(
            definition: TestFixtures.customDefinition(detection: .remembered),
            rememberedState: nil
        )

        #expect(await provider.readState(context) == .unknown)
    }

    @Test("終了コード 0 を ON とみなす", arguments: [(Int32(0), SwitchState.on), (Int32(1), SwitchState.off)])
    func exitCodeDetection(exitCode: Int32, expected: SwitchState) async {
        let runner = FakeCommandRunner.always(CommandResult(exitCode: exitCode))
        let provider = ShellSwitchProvider(runner: runner)
        let context = SwitchContext(
            definition: TestFixtures.customDefinition(detection: .exitCodeZeroMeansOn)
        )

        #expect(await provider.readState(context) == expected)
    }

    @Test("出力一致で ON とみなす")
    func outputDetection() async {
        let runner = FakeCommandRunner.always(
            CommandResult(exitCode: 0, standardOutput: " connected \n")
        )
        let provider = ShellSwitchProvider(runner: runner)
        let context = SwitchContext(
            definition: TestFixtures.customDefinition(detection: .outputEquals("connected"))
        )

        #expect(await provider.readState(context) == .on)
    }

    @Test("出力が一致しなければ OFF")
    func outputMismatch() async {
        let runner = FakeCommandRunner.always(
            CommandResult(exitCode: 0, standardOutput: "disconnected")
        )
        let provider = ShellSwitchProvider(runner: runner)
        let context = SwitchContext(
            definition: TestFixtures.customDefinition(detection: .outputEquals("connected"))
        )

        #expect(await provider.readState(context) == .off)
    }

    @Test("コマンドを起動できない場合は不明を返す")
    func unreadableStateIsUnknown() async {
        let provider = ShellSwitchProvider(runner: FakeCommandRunner.failing())
        let context = SwitchContext(
            definition: TestFixtures.customDefinition(detection: .exitCodeZeroMeansOn)
        )

        #expect(await provider.readState(context) == .unknown)
    }

    @Test("ON / OFF でそれぞれのコマンドがシェル経由で実行される")
    func applyRunsConfiguredCommand() async throws {
        let runner = FakeCommandRunner()
        let provider = ShellSwitchProvider(runner: runner)
        let context = SwitchContext(
            definition: TestFixtures.customDefinition(onCommand: "turn-on", offCommand: "turn-off")
        )

        try await provider.apply(isOn: true, context: context)
        try await provider.apply(isOn: false, context: context)

        let commands = runner.executedCommands
        #expect(commands.count == 2)
        #expect(commands[0].executable == ShellCommand.defaultShellPath)
        #expect(commands[0].arguments.last == "turn-on")
        #expect(commands[1].arguments.last == "turn-off")
    }

    @Test("終了コードが 0 以外なら適用は失敗する")
    func applyFailsOnNonZeroExit() async {
        let runner = FakeCommandRunner.always(
            CommandResult(exitCode: 3, standardError: "権限がありません")
        )
        let provider = ShellSwitchProvider(runner: runner)
        let context = SwitchContext(definition: TestFixtures.customDefinition())

        await #expect(throws: SwitchError.self) {
            try await provider.apply(isOn: true, context: context)
        }
    }

    @Test("コマンド未設定なら適用は失敗する")
    func applyFailsWithoutCommand() async {
        let provider = ShellSwitchProvider(runner: FakeCommandRunner())
        let context = SwitchContext(
            definition: TestFixtures.customDefinition().updatingCustomCommand(nil)
        )

        await #expect(throws: SwitchError.self) {
            try await provider.apply(isOn: true, context: context)
        }
    }

    @Test("サンドボックスでは利用できないと申告する")
    func availability() {
        let provider = ShellSwitchProvider(runner: FakeCommandRunner())

        #expect(provider.availability.isSandboxSafe == false)
    }
}
