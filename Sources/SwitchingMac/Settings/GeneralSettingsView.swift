import AppKit
import SwiftUI
import SwitchingMacCore

/// 一般設定タブ。
struct GeneralSettingsView: View {
    let loginItem: LoginItemController

    private var configurationFileURL: URL {
        FileConfigurationStore.defaultFileURL()
    }

    var body: some View {
        Form {
            Section {
                Toggle("ログイン時に SwitchingMac を起動", isOn: loginItemBinding)
                if let errorMessage = loginItem.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                Text("起動")
            } footer: {
                Text("メニューバーのみに常駐し、Dock とアプリスイッチャーには表示されません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("設定ファイル") {
                LabeledContent("保存場所") {
                    HStack(spacing: 8) {
                        Text(configurationFileURL.path(percentEncoded: false))
                            .font(.caption)
                            .textSelection(.enabled)
                            .lineLimit(2)
                            .truncationMode(.middle)
                        Button("開く") {
                            NSWorkspace.shared.activateFileViewerSelecting([configurationFileURL])
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { loginItem.refresh() }
    }

    private var loginItemBinding: Binding<Bool> {
        Binding(
            get: { loginItem.isEnabled },
            set: { loginItem.setEnabled($0) }
        )
    }
}
