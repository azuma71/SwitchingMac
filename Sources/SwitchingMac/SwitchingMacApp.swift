import SwiftUI
import SwitchingMacCore

@main
struct SwitchingMacApp: App {
    /// メニューバーのアイコン
    private static let menuBarSymbol = "switch.2"

    @State private var store = SwitchStore(
        registry: .makeDefault(),
        store: FileConfigurationStore()
    )
    @State private var loginItem = LoginItemController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(store: store)
        } label: {
            Image(systemName: Self.menuBarSymbol)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsWindowView(store: store, loginItem: loginItem)
        }
    }
}
