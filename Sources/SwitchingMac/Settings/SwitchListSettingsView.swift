import SwiftUI
import SwitchingMacCore

/// スイッチ一覧タブ。表示 / 非表示、並び替え、カスタムスイッチの追加・編集・削除を行う。
struct SwitchListSettingsView: View {
    let store: SwitchStore

    @State private var editorTarget: EditorTarget?
    @State private var deletionTarget: SwitchDefinition?

    /// 編集シートの対象
    private enum EditorTarget: Identifiable {
        case create
        case edit(SwitchDefinition)

        var id: String {
            switch self {
            case .create: "create"
            case let .edit(definition): definition.id
            }
        }

        var definition: SwitchDefinition? {
            switch self {
            case .create: nil
            case let .edit(definition): definition
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(store.orderedSwitches) { definition in
                    row(for: definition)
                }
                .onMove { source, destination in
                    store.moveSwitches(fromOffsets: source, toOffset: destination)
                }
            }
            .listStyle(.inset)

            Divider()
            toolbar
        }
        .sheet(item: $editorTarget) { target in
            CustomSwitchEditorView(existing: target.definition) { definition in
                if target.definition == nil {
                    try store.addSwitch(definition)
                } else {
                    try store.updateSwitch(definition)
                }
            }
        }
        .confirmationDialog(
            "スイッチを削除しますか？",
            isPresented: deletionBinding,
            presenting: deletionTarget
        ) { definition in
            Button("「\(definition.title)」を削除", role: .destructive) {
                store.removeSwitch(id: definition.id)
                deletionTarget = nil
            }
            Button("キャンセル", role: .cancel) { deletionTarget = nil }
        } message: { _ in
            Text("この操作は取り消せません。")
        }
    }

    // MARK: - 構成要素

    private func row(for definition: SwitchDefinition) -> some View {
        HStack(spacing: 10) {
            Toggle("メニューバーに表示", isOn: visibilityBinding(for: definition))
                .labelsHidden()
                .toggleStyle(.checkbox)
                .help("メニューバーに表示する")

            Image(systemName: definition.symbolName)
                .frame(width: 20)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(definition.title)
                Text(definition.kind.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let caution = definition.kind.cautionNote {
                    Text(caution)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            if definition.kind.isUserCreatable {
                Button("編集") { editorTarget = .edit(definition) }
                    .buttonStyle(.link)
                Button {
                    deletionTarget = definition
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("削除")
            }
        }
        .padding(.vertical, 2)
    }

    private var toolbar: some View {
        HStack {
            Button {
                editorTarget = .create
            } label: {
                Label("カスタムスイッチを追加", systemImage: "plus")
            }

            Spacer()

            Text("ドラッグで並び順を変更できます。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    // MARK: - Binding

    private func visibilityBinding(for definition: SwitchDefinition) -> Binding<Bool> {
        Binding(
            get: { definition.isVisibleInMenuBar },
            set: { store.setVisibility($0, forID: definition.id) }
        )
    }

    private var deletionBinding: Binding<Bool> {
        Binding(
            get: { deletionTarget != nil },
            set: { isPresented in
                if !isPresented { deletionTarget = nil }
            }
        )
    }
}
