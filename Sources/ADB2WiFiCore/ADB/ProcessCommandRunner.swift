import Foundation

public struct ProcessCommandRunner: CommandRunning {
    public init() {}

    public func run(executable: URL, arguments: [String], timeout: Duration) async throws -> CommandResult {
        try await Task.detached(priority: .userInitiated) {
            try Self.runBlocking(executable: executable, arguments: arguments, timeout: timeout)
        }.value
    }

    /// Launches `executable` directly (never `/bin/sh -c`). On timeout: SIGTERM, then SIGINT after 1s. Never SIGKILL first; never `adb kill-server`.
    private static func runBlocking(
        executable: URL,
        arguments: [String],
        timeout: Duration
    ) throws -> CommandResult {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdout = PipeBuffer()
        let stderr = PipeBuffer()
        stdout.attach(stdoutPipe)
        stderr.attach(stderrPipe)

        let group = DispatchGroup()
        group.enter()
        process.terminationHandler = { _ in group.leave() }

        do {
            try process.run()
        } catch {
            stdout.detach(stdoutPipe)
            stderr.detach(stderrPipe)
            throw error
        }

        let waitResult = group.wait(timeout: .now() + timeInterval(timeout))
        if waitResult == .timedOut {
            process.terminate()
            let afterTerm = group.wait(timeout: .now() + 1)
            if afterTerm == .timedOut {
                process.interrupt()
                _ = group.wait(timeout: .now() + 1)
            }
            stdout.detach(stdoutPipe)
            stderr.detach(stderrPipe)
            throw ADBError.timeout
        }

        return CommandResult(
            exitCode: process.terminationStatus,
            stdout: stdout.finish(stdoutPipe),
            stderr: stderr.finish(stderrPipe)
        )
    }

    private static func timeInterval(_ duration: Duration) -> TimeInterval {
        let components = duration.components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}

private final class PipeBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func attach(_ pipe: Pipe) {
        pipe.fileHandleForReading.readabilityHandler = { [self] handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
            } else {
                append(chunk)
            }
        }
    }

    func detach(_ pipe: Pipe) {
        pipe.fileHandleForReading.readabilityHandler = nil
    }

    func finish(_ pipe: Pipe) -> String {
        pipe.fileHandleForReading.readabilityHandler = nil
        if let rest = try? pipe.fileHandleForReading.readToEnd(), !rest.isEmpty {
            append(rest)
        }
        let snapshot = lock.withLock { data }
        return String(decoding: snapshot, as: UTF8.self)
    }

    private func append(_ chunk: Data) {
        lock.withLock { data.append(chunk) }
    }
}
