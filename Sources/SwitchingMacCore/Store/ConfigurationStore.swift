import Foundation

/// 設定の永続化の抽象。
public protocol ConfigurationStoring: Sendable {
    /// 保存済み設定を読み込む。未保存の場合は既定設定を返す。
    /// - Throws: `ConfigurationStoreError` 読み込みや復号に失敗した場合
    func load() throws -> SwitchConfiguration

    /// 設定を保存する。
    /// - Throws: `ConfigurationStoreError` 書き込みに失敗した場合
    func save(_ configuration: SwitchConfiguration) throws

    /// 壊れた設定ファイルを退避する。復旧の直前に呼ぶ。
    /// - Returns: 退避先。退避するものが無ければ nil。
    @discardableResult
    func quarantineCorruptedFile() throws -> URL?
}

/// 設定ファイル入出力のエラー。
public enum ConfigurationStoreError: LocalizedError, Sendable {
    case unreadable(path: String, underlying: String)
    case decodingFailed(path: String, underlying: String)
    case unwritable(path: String, underlying: String)

    public var errorDescription: String? {
        switch self {
        case let .unreadable(path, underlying):
            return "設定ファイルを読み込めませんでした: \(path)\n\(underlying)"
        case let .decodingFailed(path, underlying):
            return "設定ファイルの内容を解釈できませんでした: \(path)\n\(underlying)"
        case let .unwritable(path, underlying):
            return "設定ファイルを保存できませんでした: \(path)\n\(underlying)"
        }
    }
}

/// JSON ファイルによる設定の永続化。
///
/// 保存先は `~/Library/Application Support/SwitchingMac/switches.json`。
/// カスタムコマンドを含むため、所有者のみ読み書き可能な権限で保存する。
public struct FileConfigurationStore: ConfigurationStoring {
    private static let directoryName = "SwitchingMac"
    private static let fileName = "switches.json"
    private static let filePermissions: NSNumber = 0o600

    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public init() {
        self.init(fileURL: Self.defaultFileURL())
    }

    /// 既定の保存先。
    public static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")
        return base
            .appending(path: directoryName, directoryHint: .isDirectory)
            .appending(path: fileName, directoryHint: .notDirectory)
    }

    public var currentFileURL: URL { fileURL }

    public func load() throws -> SwitchConfiguration {
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else {
            return .makeDefault()
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw ConfigurationStoreError.unreadable(
                path: fileURL.path(percentEncoded: false),
                underlying: error.localizedDescription
            )
        }

        do {
            let decoded = try JSONDecoder().decode(SwitchConfiguration.self, from: data)
            // アプリ更新で組込スイッチが増えていても取りこぼさない。
            return decoded.mergingMissingBuiltins()
        } catch {
            throw ConfigurationStoreError.decodingFailed(
                path: fileURL.path(percentEncoded: false),
                underlying: error.localizedDescription
            )
        }
    }

    public func save(_ configuration: SwitchConfiguration) throws {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(configuration)

            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: [.atomic])
            try FileManager.default.setAttributes(
                [.posixPermissions: Self.filePermissions],
                ofItemAtPath: fileURL.path(percentEncoded: false)
            )
        } catch {
            throw ConfigurationStoreError.unwritable(
                path: fileURL.path(percentEncoded: false),
                underlying: error.localizedDescription
            )
        }
    }

    @discardableResult
    public func quarantineCorruptedFile() throws -> URL? {
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else {
            return nil
        }
        let stamp = Date().filenameSafeTimestamp
        let destination = fileURL
            .deletingLastPathComponent()
            .appending(path: "\(fileURL.lastPathComponent).corrupted-\(stamp)")

        do {
            try FileManager.default.moveItem(at: fileURL, to: destination)
        } catch {
            throw ConfigurationStoreError.unwritable(
                path: destination.path(percentEncoded: false),
                underlying: error.localizedDescription
            )
        }
        return destination
    }
}

private extension Date {
    /// ファイル名に使える形式（コロンを含まない）の時刻文字列。
    var filenameSafeTimestamp: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: self)
    }
}
