import SwiftUI
import SwitchingMacCore

/// カスタムスイッチの状態判定方法（画面上の選択肢）。
private enum DetectionMode: String, CaseIterable, Identifiable {
    case remembered
    case exitCode
    case output

    var id: String { rawValue }

    var label: String {
        switch self {
        case .remembered: "状態を取得しない（最後の操作を記憶）"
        case .exitCode: "コマンドの終了コードが 0 なら ON"
        case .output: "コマンドの出力が指定文字列と一致したら ON"
        }
    }

    var requiresStateCommand: Bool {
        self != .remembered
    }

    func detection(expectedOutput: String) -> ShellStateDetection {
        switch self {
        case .remembered: .remembered
        case .exitCode: .exitCodeZeroMeansOn
        case .output: .outputEquals(expectedOutput)
        }
    }

    static func from(_ detection: ShellStateDetection) -> DetectionMode {
        switch detection {
        case .remembered: .remembered
        case .exitCodeZeroMeansOn: .exitCode
        case .outputEquals: .output
        }
    }
}

/// 編集中の入力値。
private struct Draft {
    var title: String
    var symbolName: String
    var onCommand: String
    var offCommand: String
    var detectionMode: DetectionMode
    var stateCommand: String
    var expectedOutput: String

    init(definition: SwitchDefinition?) {
        let command = definition?.customCommand
        title = definition?.title ?? ""
        symbolName = definition?.symbolName ?? "terminal"
        onCommand = command?.onCommand ?? ""
        offCommand = command?.offCommand ?? ""
        detectionMode = command.map { DetectionMode.from($0.stateDetection) } ?? .remembered
        stateCommand = command?.stateCommand ?? ""

        if case let .outputEquals(expected) = command?.stateDetection {
            expectedOutput = expected
        } else {
            expectedOutput = ""
        }
    }
}

/// カスタムスイッチの追加 / 編集シート。
struct CustomSwitchEditorView: View {
    let existing: SwitchDefinition?
    let onSave: (SwitchDefinition) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Draft
    @State private var errorMessage: String?

    init(existing: SwitchDefinition?, onSave: @escaping (SwitchDefinition) throws -> Void) {
        self.existing = existing
        self.onSave = onSave
        _draft = State(initialValue: Draft(definition: existing))
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                appearanceSection
                commandSection
                stateSection
            }
            .formStyle(.grouped)

            if let errorMessage {
                errorView(errorMessage)
            }

            Divider()
            buttons
        }
        .frame(width: 520, height: 500)
    }

    // MARK: - 構成要素

    private var appearanceSection: some View {
        Section("表示") {
            TextField("名称", text: $draft.title, prompt: Text("例: VPN 接続"))

            LabeledContent("アイコン") {
                HStack(spacing: 8) {
                    TextField("", text: $draft.symbolName, prompt: Text("terminal"))
                        .labelsHidden()
                    Image(systemName: draft.symbolName)
                        .frame(width: 20)
                }
            }

            Text("アイコンには SF Symbols の名称を入力します（例: bolt.fill、network、lock.fill）。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var commandSection: some View {
        Section {
            commandField("ON にするコマンド", text: $draft.onCommand)
            commandField("OFF にするコマンド", text: $draft.offCommand)
        } header: {
            Text("コマンド")
        } footer: {
            Text("コマンドは /bin/zsh -lc で実行されます。自分の Mac で実行される内容を必ず確認してください。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var stateSection: some View {
        Section("現在状態の判定") {
            Picker("判定方法", selection: $draft.detectionMode) {
                ForEach(DetectionMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.radioGroup)

            if draft.detectionMode.requiresStateCommand {
                commandField("状態取得コマンド", text: $draft.stateCommand)
            }
            if draft.detectionMode == .output {
                TextField(
                    "ON とみなす出力",
                    text: $draft.expectedOutput,
                    prompt: Text("例: connected")
                )
            }
        }
    }

    private func commandField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.callout)
            TextField(title, text: text, axis: .vertical)
                .labelsHidden()
                .lineLimit(1 ... 4)
                .font(.system(.body, design: .monospaced))
        }
    }

    private func errorView(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
    }

    private var buttons: some View {
        HStack {
            Spacer()
            Button("キャンセル", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("保存") { save() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(12)
    }

    // MARK: - 保存

    private func save() {
        let definition = makeDefinition()
        do {
            try definition.validate()
            try onSave(definition)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func makeDefinition() -> SwitchDefinition {
        let spec = CustomCommandSpec(
            onCommand: draft.onCommand,
            offCommand: draft.offCommand,
            stateCommand: draft.detectionMode.requiresStateCommand ? draft.stateCommand : "",
            stateDetection: draft.detectionMode.detection(expectedOutput: draft.expectedOutput)
        )

        if let existing {
            return existing
                .updatingTitle(draft.title)
                .updatingSymbolName(draft.symbolName)
                .updatingCustomCommand(spec)
        }
        return .custom(
            title: draft.title,
            symbolName: draft.symbolName,
            command: spec
        )
    }
}
