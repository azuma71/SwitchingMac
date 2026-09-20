import Foundation
import Testing
@testable import SwitchingMacCore

@Suite("組込スイッチ")
struct BuiltinProviderTests {
    private func context(for kind: SwitchKind) -> SwitchContext {
        let definition = BuiltinSwitchCatalog.definition(for: kind)!
        return SwitchContext(definition: definition)
    }

    // MARK: - ダークモード

    @Test("AppleInterfaceStyle が Dark なら ON")
    func darkModeReadsOn() async {
        let runner = FakeCommandRunner.always(
            CommandResult(exitCode: 0, standardOutput: "Dark\n")
        )
        let provider = DarkModeProvider(runner: runner)

        #expect(await provider.readState(context(for: .darkMode)) == .on)
    }

    @Test("キーが存在しない（終了コード 1）なら OFF")
    func darkModeReadsOffWhenKeyMissing() async {
        let runner = FakeCommandRunner.always(CommandResult(exitCode: 1))
        let provider = DarkModeProvider(runner: runner)

        #expect(await provider.readState(context(for: .darkMode)) == .off)
    }

    @Test("適用時は osascript でシステムイベントを操作する")
    func darkModeAppliesViaAppleScript() async throws {
        let runner = FakeCommandRunner()
        let provider = DarkModeProvider(runner: runner)

        try await provider.apply(isOn: true, context: context(for: .darkMode))

        let command = try #require(runner.lastCommand)
        #expect(command.executable == "/usr/bin/osascript")
        #expect(command.arguments.first == "-e")
        #expect(command.arguments.last?.contains("set dark mode to true") == true)
    }

    @Test("自動化が許可されていない場合は権限エラーに読み替える")
    func darkModeMapsPermissionError() async {
        let runner = FakeCommandRunner.always(
            CommandResult(exitCode: 1, standardError: "execution error: ... (-1743)")
        )
        let provider = DarkModeProvider(runner: runner)

        await #expect(throws: SwitchError.permissionDenied(
            reason: "「システム設定 > プライバシーとセキュリティ > オートメーション」で "
                + "SwitchingMac に「システムイベント」の操作を許可してください。"
        )) {
            try await provider.apply(isOn: true, context: context(for: .darkMode))
        }
    }

    // MARK: - defaults 系

    @Test("defaults の値 1 を ON とみなす")
    func defaultsToggleReadsOn() async {
        let runner = FakeCommandRunner.always(CommandResult(exitCode: 0, standardOutput: "1\n"))
        let provider = DefaultsToggleProvider.hiddenFiles(runner: runner)

        #expect(await provider.readState(context(for: .hiddenFiles)) == .on)
    }

    @Test("キーが未設定なら OS の既定値を返す")
    func defaultsToggleFallsBack() async {
        let runner = FakeCommandRunner.always(CommandResult(exitCode: 1))
        let provider = DefaultsToggleProvider.dockAutohide(runner: runner)

        #expect(await provider.readState(context(for: .dockAutohide)) == .off)
    }

    @Test("適用時は defaults write と対象プロセスの再起動を行う")
    func defaultsToggleWritesAndRestarts() async throws {
        let runner = FakeCommandRunner()
        let provider = DefaultsToggleProvider.hiddenFiles(runner: runner)

        try await provider.apply(isOn: true, context: context(for: .hiddenFiles))

        let commands = runner.executedCommands
        #expect(commands.count == 2)
        #expect(commands[0].arguments == ["write", "com.apple.finder", "AppleShowAllFiles", "-bool", "YES"])
        #expect(commands[1].executable == "/usr/bin/killall")
        #expect(commands[1].arguments == ["Finder"])
    }

    @Test("Dock 用の設定値を書き込む")
    func dockAutohideWritesDockDomain() async throws {
        let runner = FakeCommandRunner()
        let provider = DefaultsToggleProvider.dockAutohide(runner: runner)

        try await provider.apply(isOn: false, context: context(for: .dockAutohide))

        let commands = runner.executedCommands
        #expect(commands[0].arguments == ["write", "com.apple.dock", "autohide", "-bool", "NO"])
        #expect(commands[1].arguments == ["Dock"])
    }

    @Test("書き込みに失敗した場合はエラーを投げる")
    func defaultsToggleThrowsOnWriteFailure() async {
        let runner = FakeCommandRunner.always(CommandResult(exitCode: 1, standardError: "失敗"))
        let provider = DefaultsToggleProvider.hiddenFiles(runner: runner)

        await #expect(throws: SwitchError.self) {
            try await provider.apply(isOn: true, context: context(for: .hiddenFiles))
        }
    }

    // MARK: - Wi-Fi

    @Test("Wi-Fi の電源状態を読み取る")
    func wifiReadsPowerState() async {
        let provider = WiFiProvider(controller: FakeWiFiController(poweredOn: true))

        #expect(await provider.readState(context(for: .wifi)) == .on)
    }

    @Test("インターフェースが無ければ利用不可を返す")
    func wifiUnavailable() async {
        let controller = FakeWiFiController(
            readError: .unavailable(reason: "Wi-Fi インターフェースが見つかりません。")
        )
        let provider = WiFiProvider(controller: controller)

        #expect(
            await provider.readState(context(for: .wifi))
                == .unavailable(reason: "Wi-Fi インターフェースが見つかりません。")
        )
    }

    @Test("Wi-Fi の電源を切り替える")
    func wifiAppliesPower() async throws {
        let controller = FakeWiFiController(poweredOn: false)
        let provider = WiFiProvider(controller: controller)

        try await provider.apply(isOn: true, context: context(for: .wifi))

        #expect(controller.currentPowerState == true)
    }

    // MARK: - スリープ防止

    @Test("スリープ防止はサンドボックスでも利用できる")
    func sleepPreventionIsSandboxSafe() {
        #expect(SleepPreventionProvider().availability == .sandboxSafe)
    }

    @Test("初期状態は OFF で、ON にすると状態が変わる")
    func sleepPreventionTogglesState() async throws {
        let provider = SleepPreventionProvider()
        let switchContext = context(for: .preventSleep)

        #expect(await provider.readState(switchContext) == .off)

        try await provider.apply(isOn: true, context: switchContext)
        #expect(await provider.readState(switchContext) == .on)

        try await provider.apply(isOn: false, context: switchContext)
        #expect(await provider.readState(switchContext) == .off)
    }
}
