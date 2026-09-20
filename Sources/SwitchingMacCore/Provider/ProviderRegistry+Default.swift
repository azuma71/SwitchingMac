import Foundation

public extension ProviderRegistry {
    /// 非サンドボックス版（Developer ID 配布）で利用する既定のレジストリ。
    static func makeDefault(
        runner: any CommandRunning = ProcessCommandRunner()
    ) -> ProviderRegistry {
        ProviderRegistry(providers: [
            DarkModeProvider(runner: runner),
            SleepPreventionProvider(),
            WiFiProvider(),
            DefaultsToggleProvider.hiddenFiles(runner: runner),
            DefaultsToggleProvider.dockAutohide(runner: runner),
            ShellSwitchProvider(runner: runner),
        ])
    }

    /// 将来の App Store 版で利用するレジストリ。サンドボックスで動作する機能のみを登録する。
    static func makeSandboxSafe(
        runner: any CommandRunning = ProcessCommandRunner()
    ) -> ProviderRegistry {
        makeDefault(runner: runner).filteringSandboxSafeOnly()
    }
}
