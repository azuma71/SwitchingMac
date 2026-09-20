import SwitchingMacCore

extension SwitchKind {
    /// 設定画面で表示する種別名。
    var displayName: String {
        switch self {
        case .darkMode: "外観"
        case .preventSleep: "電源"
        case .preventLidSleep: "電源"
        case .wifi: "ネットワーク"
        case .hiddenFiles: "Finder"
        case .dockAutohide: "Dock"
        case .custom: "カスタム"
        }
    }

    /// 利用前に知っておいてほしい注意事項。
    var cautionNote: String? {
        switch self {
        case .preventLidSleep:
            "切り替えのたびに管理者パスワードが必要です。蓋を閉じたまま動作し続けるため、通気の確保にご注意ください。"
        case .darkMode:
            "初回の切り替え時に「システムイベント」の操作許可を求められます。"
        case .hiddenFiles, .dockAutohide:
            "設定を反映するため、対象のプロセスを再起動します。"
        case .preventSleep, .wifi, .custom:
            nil
        }
    }
}
