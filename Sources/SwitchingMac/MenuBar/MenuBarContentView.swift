import AppKit
import SwiftUI
import SwitchingMacCore

/// メニューバーアイコンをクリックしたときに表示される本体。
struct MenuBarContentView: View {
    let store: SwitchStore

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let errorMessage = store.errorMessage {
                errorBanner(errorMessage)
                Divider()
            }

            switchSection

            Divider()
            footer
        }
        .frame(width: 300)
        .task { await store.refreshStates() }
    }

    // MARK: - 構成要素

    @ViewBuilder
    private var switchSection: some View {
        if store.menuBarSwitches.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                ForEach(store.menuBarSwitches) { definition in
                    SwitchRowView(
                        definition: definition,
                        state: store.state(forID: definition.id),
                        isBusy: store.isBusy(id: definition.id),
                        onChange: { isOn in
                            Task { await store.setState(isOn, forID: definition.id) }
                        }
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("表示するスイッチがありません")
                .font(.callout)
            Text("設定画面でスイッチの表示を有効にしてください。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button {
                store.dismissError()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            menuButton("設定…", symbol: "gearshape") {
                NSApp.activate()
                openSettings()
            }
            menuButton("SwitchingMac を終了", symbol: "power") {
                NSApp.terminate(nil)
            }
        }
        .padding(.vertical, 4)
    }

    private func menuButton(
        _ title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .frame(width: 20)
                Text(title)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
