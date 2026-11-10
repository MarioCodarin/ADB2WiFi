import Darwin
import Foundation

public struct ProcessCommandRunner: CommandRunning {
    /// Guardrail so a chatty child can never grow the menu-bar app without bound.
    private static let outputLimit = 256 * 1024
    private static let readChunk = 64 * 1024
    private static let killGrace: Duration = .seconds(1)

    public init() {}

    public func run(executable: URL, arguments: [String], timeout: Duration) async throws -> CommandResult {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let exit = ExitSignal()
        process.terminationHandler = { _ in exit.signal() }

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.closeFile()
            stderrPipe.fileHandleForReading.closeFile()
            exit.signal()
            throw ADBError.launchFailed(error.localizedDescription)
        }

        // Drain both pipes concurrently. This avoids the classic race where a
        // termination handler resumes before `readToEnd`/readability handlers have
        // delivered the last chunk.
        let stdoutReader = Task.detached(priority: .utility) {
            Self.readAll(stdoutPipe.fileHandleForReading, limit: Self.outputLimit)
        }
        let stderrReader = Task.detached(priority: .utility) {
            Self.readAll(stderrPipe.fileHandleForReading, limit: Self.outputLimit)
        }

        let timedOut = TimeoutFlag()
        let watchdog = Task {
            do {
                try await Task.sleep(for: timeout)
            } catch {
                return
            }
            timedOut.set()
            Self.signal(process, SIGTERM)
            try? await Task.sleep(for: Self.killGrace)
            Self.signal(process, SIGINT)
            try? await Task.sleep(for: Self.killGrace)
            Self.signal(process, SIGKILL)
        }

        await withTaskCancellationHandler {
            await exit.wait()
        } onCancel: {
            Self.signal(process, SIGTERM)
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                Self.signal(process, SIGKILL)
            }
        }
        watchdog.cancel()

        let stdout = await stdoutReader.value
        let stderr = await stderrReader.value

        if timedOut.isSet { throw ADBError.timeout }
        try Task.checkCancellation()

        return CommandResult(
            exitCode: process.terminationStatus,
            stdout: stdout,
            stderr: stderr
        )
    }

    private static func readAll(_ handle: FileHandle, limit: Int) -> String {
        var data = Data()
        var truncated = false

        while true {
            let chunk: Data
            do {
                chunk = try handle.read(upToCount: readChunk) ?? Data()
            } catch {
                break
            }
            guard !chunk.isEmpty else { break }

            let remaining = limit - data.count
            if remaining <= 0 {
                truncated = true
                continue
            }
            if chunk.count > remaining {
                data.append(contentsOf: chunk.prefix(remaining))
                truncated = true
            } else {
                data.append(chunk)
            }
        }

        var text = String(decoding: data, as: UTF8.self)
        if truncated {
            text += "\n[output truncated at \(limit / 1024) KB]"
        }
        return text
    }

    private static func signal(_ process: Process, _ signal: Int32) {
        guard process.isRunning else { return }
        kill(process.processIdentifier, signal)
    }
}

/// Resumed exactly once, from the process termination handler or after a failed launch.
private final class ExitSignal: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    private var signaled = false

    func wait() async {
        await withCheckedContinuation { continuation in
            let alreadySignaled = lock.withLock { () -> Bool in
                if signaled { return true }
                self.continuation = continuation
                return false
            }
            if alreadySignaled { continuation.resume() }
        }
    }

    func signal() {
        let pending: CheckedContinuation<Void, Never>? = lock.withLock {
            guard !signaled else { return nil }
            signaled = true
            let continuation = self.continuation
            self.continuation = nil
            return continuation
        }
        pending?.resume()
    }
}

private final class TimeoutFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func set() { lock.withLock { value = true } }
    var isSet: Bool { lock.withLock { value } }
}
