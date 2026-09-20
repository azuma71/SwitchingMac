import Foundation

/// 組込プリセットスイッチの既定値カタログ。
///
/// 表示名やアイコンの既定値をここに集約し、初回起動時および
/// アプリ更新で組込スイッチが増えた際の補完に用いる。
public enum BuiltinSwitchCatalog {
    /// 組込スイッチの既定定義（表示順）。
    public static let definitions: [SwitchDefinition] = [
        .builtin(
            kind: .darkMode,
            title: "ダークモード",
            symbolName: "moon.fill",
            sortOrder: 0
        ),
        .builtin(
            kind: .preventSleep,
            title: "スリープ防止",
            symbolName: "cup.and.saucer.fill",
            sortOrder: 1
        ),
        .builtin(
            kind: .wifi,
            title: "Wi-Fi",
            symbolName: "wifi",
            sortOrder: 2
        ),
        .builtin(
            kind: .hiddenFiles,
            title: "隠しファイルを表示",
            symbolName: "eye.fill",
            sortOrder: 3
        ),
        .builtin(
            kind: .dockAutohide,
            title: "Dock を自動的に非表示",
            symbolName: "dock.rectangle",
            sortOrder: 4
        ),
    ]

    /// 指定種別の既定定義を返す。
    public static func definition(for kind: SwitchKind) -> SwitchDefinition? {
        definitions.first { $0.kind == kind }
    }
}
