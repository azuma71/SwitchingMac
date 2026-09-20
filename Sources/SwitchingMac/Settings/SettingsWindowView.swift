import SwiftUI
import SwitchingMacCore

/// 設定ウィンドウ。
struct SettingsWindowView: View {
    let store: SwitchStore
    let loginItem: LoginItemController

    var body: some View {
        TabView {
            GeneralSettingsView(loginItem: loginItem)
                .tabItem { Label("一般", systemImage: "gearshape") }

            SwitchListSettingsView(store: store)
                .tabItem { Label("スイッチ", systemImage: "switch.2") }

            AboutSettingsView()
                .tabItem { Label("情報", systemImage: "info.circle") }
        }
        .frame(width: 560, height: 420)
    }
}
