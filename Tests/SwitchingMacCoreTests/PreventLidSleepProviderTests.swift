import Foundation
import Testing
@testable import SwitchingMacCore

@Suite("蓋を閉じてもスリープしない")
struct PreventLidSleepProviderTests {
    private var context: SwitchContext {
        SwitchContext(definition: BuiltinSwitchCatalog.definition(for: .preventLidSleep)!)
    }

    /// `pmset -g` の出力を模したもの。値はタブ区切りで並ぶ。
    private func pmsetOutput(sleepDisabled: String?) -> String {
        var lines = ["System-wide power settings:"]
        if let sleepDisabled {
            lines.append(" SleepDisabled\t\t\(sleepDisabled)")
        }
        lines.append(contentsOf: [
            "Currently in use:",
            " standby              1",
            " sleep                0 (sleep prevented by powerd)",
        ])
        return lines.joined(separator: "\n")
    }

    @Test("SleepDisabled が 1 なら ON")
    func readsOnWhenDisabled() async {
        let runner = FakeCommandRunner.always(
            CommandResult(exitCode: 0, standardOutput: pmsetOutput(sleepDisabled: "1"))
        )
        let provider = PreventLidSleepProvider(runner: runner)

        #expect(await provider.readState(context) == .on)
    }

    @Test("SleepDisabled が 0 なら OFF")
    func readsOffWhenEnabled() async {
        let runner = FakeCommandRunner.always(
            CommandResult(exitCode: 0, standardOutput: pmsetOutput(sleepDisabled: "0"))
        )
        let provider = PreventLidSleepProvider(runner: runner)

        #expect(await provider.readState(context) == .off)
    }

    @Test("SleepDisabled の行が無ければ OFF")
    func readsOffWhenKeyMissing() async {
        let runner = FakeCommandRunner.always(
            CommandResult(exitCode: 0, standardOutput: pmsetOutput(sleepDisabled: nil))
        )
        let provider = PreventLidSleepProvider(runner: runner)

        #expect(await provider.readState(context) == .off)
    }

    @Test("状態取得コマンドが失敗したら不明を返す")
    func readsUnknownOnFailure() async {
        let provider = PreventLidSleepProvider(runner: FakeCommandRunner.failing())

        #expect(await provider.readState(context) == .unknown)
    }

    @Test("状態取得は権限を要求しない pmset -g を使う")
    func readUsesPlainPmset() async {
        let runner = FakeCommandRunner.always(
            CommandResult(exitCode: 0, standardOutput: pmsetOutput(sleepDisabled: "1"))
        )
        let provider = PreventLidSleepProvider(runner: runner)

        _ = await provider.readState(context)

        let command = runner.lastCommand
        #expect(command?.executable == "/usr/bin/pmset")
        #expect(command?.arguments == ["-g"])
    }

    @Test("ON にすると管理者権限付きで disablesleep 1 を実行する")
    func applyOnUsesAdministratorPrivileges() async throws {
        let runner = FakeCommandRunner()
        let provider = PreventLidSleepProvider(runner: runner)

        try await provider.apply(isOn: true, context: context)

        let command = try #require(runner.lastCommand)
        let script = try #require(command.arguments.last)
        #expect(command.executable == "/usr/bin/osascript")
        #expect(script.contains("/usr/bin/pmset -a disablesleep 1"))
        #expect(script.contains("with administrator privileges"))
    }

    @Test("OFF にすると disablesleep 0 を実行する")
    func applyOffRestoresSleep() async throws {
        let runner = FakeCommandRunner()
        let provider = PreventLidSleepProvider(runner: runner)

        try await provider.apply(isOn: false, context: context)

        let script = try #require(runner.lastCommand?.arguments.last)
        #expect(script.contains("/usr/bin/pmset -a disablesleep 0"))
    }

    @Test("パスワード入力のキャンセルは分かりやすいエラーになる")
    func cancelledAuthenticationIsReported() async {
        let runner = FakeCommandRunner.always(
            CommandResult(exitCode: 1, standardError: "execution error: User canceled. (-128)")
        )
        let provider = PreventLidSleepProvider(runner: runner)

        await #expect(throws: SwitchError.permissionDenied(
            reason: "管理者パスワードの入力がキャンセルされました。"
        )) {
            try await provider.apply(isOn: true, context: context)
        }
    }

    @Test("権限昇格が必要なためサンドボックスでは利用できない")
    func availability() {
        let provider = PreventLidSleepProvider(runner: FakeCommandRunner())

        #expect(provider.availability.isSandboxSafe == false)
    }
}
