import Foundation
@testable import SwitchingMacCore

/// 実行されたコマンドを記録し、応答を差し替えられるフェイク。
final class FakeCommandRunner: CommandRunning, @unchecked Sendable {
    typealias Responder = @Sendable (ShellCommand) -> Result<CommandResult, SwitchError>

    private let lock = NSLock()
    private var recorded: [ShellCommand] = []
    private let responder: Responder

    init(responder: @escaping Responder = { _ in .success(CommandResult(exitCode: 0)) }) {
        self.responder = responder
    }

    /// 常に同じ結果を返すフェイク。
    static func always(_ result: CommandResult) -> FakeCommandRunner {
        FakeCommandRunner { _ in .success(result) }
    }

    /// 常に起動失敗するフェイク。
    static func failing(reason: String = "not executable") -> FakeCommandRunner {
        FakeCommandRunner { command in
            .failure(.commandNotExecutable(command: command.displayString, reason: reason))
        }
    }

    var executedCommands: [ShellCommand] {
        lock.withLock { recorded }
    }

    var lastCommand: ShellCommand? {
        lock.withLock { recorded.last }
    }

    func run(_ command: ShellCommand) async throws -> CommandResult {
        lock.withLock { recorded.append(command) }
        return try responder(command).get()
    }
}

/// Wi-Fi 制御のフェイク。
final class FakeWiFiController: WiFiControlling, @unchecked Sendable {
    private let lock = NSLock()
    private var poweredOn: Bool
    private let readError: SwitchError?
    private let writeError: SwitchError?

    init(poweredOn: Bool = false, readError: SwitchError? = nil, writeError: SwitchError? = nil) {
        self.poweredOn = poweredOn
        self.readError = readError
        self.writeError = writeError
    }

    var currentPowerState: Bool {
        lock.withLock { poweredOn }
    }

    func isPoweredOn() throws -> Bool {
        if let readError { throw readError }
        return lock.withLock { poweredOn }
    }

    func setPower(_ isOn: Bool) throws {
        if let writeError { throw writeError }
        lock.withLock { poweredOn = isOn }
    }
}

/// メモリ上に設定を保持するストア。
final class InMemoryConfigurationStore: ConfigurationStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: SwitchConfiguration?
    private let loadError: (any Error)?
    private let saveError: (any Error)?
    private var quarantineCount = 0

    init(
        initial: SwitchConfiguration? = nil,
        loadError: (any Error)? = nil,
        saveError: (any Error)? = nil
    ) {
        stored = initial
        self.loadError = loadError
        self.saveError = saveError
    }

    var savedConfiguration: SwitchConfiguration? {
        lock.withLock { stored }
    }

    var quarantineCallCount: Int {
        lock.withLock { quarantineCount }
    }

    func load() throws -> SwitchConfiguration {
        if let loadError { throw loadError }
        return lock.withLock { stored } ?? .makeDefault()
    }

    func save(_ configuration: SwitchConfiguration) throws {
        if let saveError { throw saveError }
        lock.withLock { stored = configuration }
    }

    @discardableResult
    func quarantineCorruptedFile() throws -> URL? {
        lock.withLock { quarantineCount += 1 }
        return URL(filePath: "/tmp/switches.json.corrupted")
    }
}

/// 呼び出しを記録するだけの `SwitchProvider`。
final class FakeSwitchProvider: SwitchProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var state: SwitchState
    private var appliedValues: [Bool] = []
    private let applyError: SwitchError?

    let kind: SwitchKind
    let availability: ProviderAvailability

    init(
        kind: SwitchKind,
        state: SwitchState = .off,
        availability: ProviderAvailability = .sandboxSafe,
        applyError: SwitchError? = nil
    ) {
        self.kind = kind
        self.state = state
        self.availability = availability
        self.applyError = applyError
    }

    var recordedApplications: [Bool] {
        lock.withLock { appliedValues }
    }

    func readState(_ context: SwitchContext) async -> SwitchState {
        lock.withLock { state }
    }

    func apply(isOn: Bool, context: SwitchContext) async throws {
        if let applyError { throw applyError }
        lock.withLock {
            appliedValues.append(isOn)
            state = .from(isOn: isOn)
        }
    }
}

/// テスト用のカスタムスイッチ定義を組み立てる。
enum TestFixtures {
    static func customDefinition(
        id: String = "custom-test",
        title: String = "テストスイッチ",
        onCommand: String = "echo on",
        offCommand: String = "echo off",
        stateCommand: String = "echo state",
        detection: ShellStateDetection = .remembered
    ) -> SwitchDefinition {
        SwitchDefinition.custom(
            identifier: id,
            title: title,
            command: CustomCommandSpec(
                onCommand: onCommand,
                offCommand: offCommand,
                stateCommand: stateCommand,
                stateDetection: detection
            )
        )
    }
}
