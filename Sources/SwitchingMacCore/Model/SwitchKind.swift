import Foundation

/// スイッチが操作する機能の種別。
///
/// `custom` 以外は組込プリセットであり、`SwitchProvider` の実装が 1 対 1 で対応する。
/// `custom` はユーザーが定義したシェルコマンドによるスイッチで、複数個作成できる。
public enum SwitchKind: String, Codable, Sendable, CaseIterable {
    /// システム外観のライト / ダーク切替
    case darkMode
    /// スリープ・画面オフの抑止
    case preventSleep
    /// Wi-Fi インターフェースの電源
    case wifi
    /// Finder の隠しファイル表示
    case hiddenFiles
    /// Dock の自動的に非表示
    case dockAutohide
    /// ユーザー定義のシェルコマンドによるスイッチ
    case custom

    /// ユーザーが自由に追加・削除できる種別かどうか。
    ///
    /// 組込プリセットは設定上 1 個だけ存在し、表示 / 非表示のみ切り替える。
    public var isUserCreatable: Bool {
        self == .custom
    }
}
