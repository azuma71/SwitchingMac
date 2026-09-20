import Foundation
import Testing
@testable import SwitchingMacCore

@Suite("設定ファイルの入出力")
struct FileConfigurationStoreTests {
    /// テストごとに独立した一時ディレクトリを使う。
    private func withTemporaryStore(
        _ body: (FileConfigurationStore, URL) throws -> Void
    ) throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "SwitchingMacTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let fileURL = directory.appending(path: "switches.json", directoryHint: .notDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }

        try body(FileConfigurationStore(fileURL: fileURL), fileURL)
    }

    @Test("保存した設定をそのまま読み込める")
    func saveAndLoad() throws {
        try withTemporaryStore { store, _ in
            let configuration = SwitchConfiguration.makeDefault()
                .adding(TestFixtures.customDefinition())
                .updatingRememberedState(true, forID: "custom-test")

            try store.save(configuration)

            let loaded = try store.load()
            #expect(loaded == configuration)
        }
    }

    @Test("ファイルが無い場合は既定設定を返す")
    func loadWithoutFileReturnsDefault() throws {
        try withTemporaryStore { store, _ in
            let loaded = try store.load()
            #expect(loaded == .makeDefault())
        }
    }

    @Test("組込スイッチが欠けたファイルは読み込み時に補完される")
    func loadMergesMissingBuiltins() throws {
        try withTemporaryStore { store, _ in
            let partial = SwitchConfiguration(switches: [
                BuiltinSwitchCatalog.definition(for: .darkMode)!,
            ])
            try store.save(partial)

            let loaded = try store.load()

            #expect(loaded.switches.count == BuiltinSwitchCatalog.definitions.count)
        }
    }

    @Test("壊れたファイルは解釈エラーになる")
    func corruptedFileThrows() throws {
        try withTemporaryStore { store, fileURL in
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data("これは JSON ではありません".utf8).write(to: fileURL)

            #expect(throws: ConfigurationStoreError.self) { try store.load() }
        }
    }

    @Test("壊れたファイルを退避できる")
    func quarantineMovesFile() throws {
        try withTemporaryStore { store, fileURL in
            try store.save(.makeDefault())

            let quarantined = try #require(try store.quarantineCorruptedFile())

            #expect(FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) == false)
            #expect(FileManager.default.fileExists(atPath: quarantined.path(percentEncoded: false)))
        }
    }

    @Test("退避対象が無ければ nil を返す")
    func quarantineWithoutFile() throws {
        try withTemporaryStore { store, _ in
            let quarantined = try store.quarantineCorruptedFile()
            #expect(quarantined == nil)
        }
    }

    @Test("設定ファイルは所有者のみ読み書き可能にする")
    func filePermissionsAreRestrictive() throws {
        try withTemporaryStore { store, fileURL in
            try store.save(.makeDefault())

            let attributes = try FileManager.default
                .attributesOfItem(atPath: fileURL.path(percentEncoded: false))
            let permissions = attributes[.posixPermissions] as? NSNumber

            #expect(permissions?.int16Value == 0o600)
        }
    }
}
