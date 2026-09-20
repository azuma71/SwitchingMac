import Foundation

/// バンドル情報の参照。
public enum AppInfo {
    public static let repositoryURL = URL(string: "https://github.com/azuma71/SwitchingMac")!

    public static var displayName: String {
        bundleString(for: "CFBundleDisplayName") ?? "SwitchingMac"
    }

    public static var version: String {
        bundleString(for: "CFBundleShortVersionString") ?? "-"
    }

    public static var build: String {
        bundleString(for: "CFBundleVersion") ?? "-"
    }

    private static func bundleString(for key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
