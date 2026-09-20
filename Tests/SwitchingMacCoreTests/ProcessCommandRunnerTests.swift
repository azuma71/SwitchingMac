import Foundation
import Testing
@testable import SwitchingMacCore

@Suite("プロセス実行")
struct ProcessCommandRunnerTests {
    @Test("標準出力と終了コードを取得できる")
    func capturesStandardOutput() async throws {
        let runner = ProcessCommandRunner()

        let result = try await runner.run(.tool("/bin/echo", ["こんにちは"]))

        #expect(result.exitCode == 0)
        #expect(result.trimmedOutput == "こんにちは")
        #expect(result.isSuccess)
    }

    @Test("0 以外の終了コードを取得できる")
    func capturesFailureExitCode() async throws {
        let runner = ProcessCommandRunner()

        let result = try await runner.run(.shell("exit 7"))

        #expect(result.exitCode == 7)
        #expect(result.isSuccess == false)
    }

    @Test("標準エラー出力を取得できる")
    func capturesStandardError() async throws {
        let runner = ProcessCommandRunner()

        let result = try await runner.run(.shell("echo 失敗しました 1>&2; exit 1"))

        #expect(result.standardError.contains("失敗しました"))
    }

    @Test("起動できないコマンドはエラーになる")
    func missingExecutableThrows() async {
        let runner = ProcessCommandRunner()

        await #expect(throws: SwitchError.self) {
            try await runner.run(.tool("/usr/bin/this-command-does-not-exist"))
        }
    }

    @Test("タイムアウトしたコマンドは中断される")
    func timeoutTerminatesProcess() async {
        let runner = ProcessCommandRunner(timeout: 0.3)

        await #expect(throws: SwitchError.self) {
            try await runner.run(.shell("sleep 5"))
        }
    }

    @Test("成功を期待する実行は失敗時にエラーを投げる")
    func runExpectingSuccessThrowsOnFailure() async {
        let runner = ProcessCommandRunner()

        await #expect(throws: SwitchError.self) {
            try await runner.runExpectingSuccess(.shell("exit 1"))
        }
    }

    @Test("大きな出力でも取りこぼさない")
    func handlesLargeOutput() async throws {
        let runner = ProcessCommandRunner()

        let result = try await runner.run(.shell("seq 1 20000"))

        #expect(result.exitCode == 0)
        #expect(result.trimmedOutput.hasSuffix("20000"))
    }

    @Test("シェル経由のコマンドは -lc で実行される")
    func shellCommandShape() {
        let command = ShellCommand.shell("echo hi")

        #expect(command.executable == "/bin/zsh")
        #expect(command.arguments == ["-lc", "echo hi"])
        #expect(command.displayString == "/bin/zsh -lc echo hi")
    }
}
