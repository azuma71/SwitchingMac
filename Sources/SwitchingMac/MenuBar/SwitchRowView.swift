import SwiftUI
import SwitchingMacCore

/// メニュー内のスイッチ 1 行。
struct SwitchRowView: View {
    let definition: SwitchDefinition
    let state: SwitchState
    let isBusy: Bool
    let onChange: (Bool) -> Void

    private var isEnabled: Bool {
        state.isOperable && !isBusy
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: definition.symbolName)
                .font(.body)
                .frame(width: 20)
                .foregroundStyle(state.isOn ? Color.accentColor : .secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(definition.title)
                    .lineLimit(1)
                if let note = unavailableReason {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            if isBusy {
                ProgressView()
                    .controlSize(.small)
            }

            Toggle("", isOn: binding)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(!isEnabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(.rect)
        .help(helpText)
    }

    private var binding: Binding<Bool> {
        Binding(
            get: { state.isOn },
            set: { onChange($0) }
        )
    }

    private var unavailableReason: String? {
        if case let .unavailable(reason) = state { return reason }
        return nil
    }

    private var helpText: String {
        if let unavailableReason { return unavailableReason }
        if state == .unknown { return "\(definition.title): 状態を取得できませんでした" }
        return "\(definition.title): \(state.isOn ? "ON" : "OFF")"
    }
}
