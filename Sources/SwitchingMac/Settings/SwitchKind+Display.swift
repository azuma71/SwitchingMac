import SwitchingMacCore

extension SwitchKind {
    /// 設定画面で表示する種別名。
    var displayName: String {
        switch self {
        case .darkMode: "外観"
        case .preventSleep: "電源"
        case .wifi: "ネットワーク"
        case .hiddenFiles: "Finder"
        case .dockAutohide: "Dock"
        case .custom: "カスタム"
        }
    }
}
