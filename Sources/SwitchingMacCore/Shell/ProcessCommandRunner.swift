import Foundation

/// `Process` による実行。タイムアウトを超えたプロセスは強制終了する。
public struct ProcessCommandRunner: CommandRunning {
    /// 既定のタイムアウト秒数
    public static let defaultTimeout: TimeInterval = 15

    private static let queue = DispatchQueue(
        label: "com.azuma71.SwitchingMac.command",
        qos: .userInitiated,
        attributes: .concurrent
    )

    public let timeout: TimeInterval

    public init(timeout: TimeInterval = ProcessCommandRunner.defaultTimeout) {
        self.timeout = timeout
    }

    public func run(_ command: ShellCommand) async throws -> CommandResult {
        let timeout = self.timeout
        return try await withCheckedThrowingContinuation { continuation in
            Self.queue.async {
                do {
                    let result = try Self.execute(command, timeout: timeout)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - 内部

    private static func execute(_ command: ShellCommand, timeout: TimeInterval) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments
        process.standardInput = FileHandle.nullDevice

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw SwitchError.commandNotExecutable(
                command: command.displayString,
                reason: error.localizedDescription
            )
        }

        let didTimeout = TimeoutFlag()
        queue.asyncAfter(deadline: .now() + timeout) {
            guard process.isRunning else { return }
            didTimeout.markTimedOut()
            process.terminate()
        }

        // パイプのバッファが埋まると子プロセスが停止するため、終了待ちより先に読み切る。
        let outputData = (try? outputPipe.fileHandleForReading.readToEnd()) ?? Data()
        let errorData = (try? errorPipe.fileHandleForReading.readToEnd()) ?? Data()
        process.waitUntilExit()

        if didTimeout.isTimedOut {
            throw SwitchError.commandFailed(
                command: command.displayString,
                exitCode: process.terminationStatus,
                message: "\(Int(timeout)) 秒以内に終了しなかったため中断しました。"
            )
        }

        return CommandResult(
            exitCode: process.terminationStatus,
            standardOutput: String(decoding: outputData, as: UTF8.self),
            standardError: String(decoding: errorData, as: UTF8.self)
        )
    }

    /// タイムアウト判定をスレッド間で安全に共有するための小さな箱。
    private final class TimeoutFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var value = false

        var isTimedOut: Bool {
            lock.withLock { value }
        }

        func markTimedOut() {
            lock.withLock { value = true }
        }
    }
}
