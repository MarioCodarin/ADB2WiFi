import Darwin
import Foundation

public struct ProcessCommandRunner: CommandRunning {
    /// Guardrail so a chatty child can never grow the menu-bar app without bound.
    private static let outputLimit = 256 * 1024
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

        let stdout = PipeBuffer(limit: Self.outputLimit)
        let stderr = PipeBuffer(limit: Self.outputLimit)
        stdout.attach(stdoutPipe)
        stderr.attach(stderrPipe)

        let exit = ExitSignal()
        process.terminationHandler = { _ in exit.signal() }

        do {
            try process.run()
        } catch {
            stdout.detach(stdoutPipe)
            stderr.detach(stderrPipe)
            exit.signal()
            throw ADBError.launchFailed(error.localizedDescription)
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

        let stdoutText = stdout.finish(stdoutPipe)
        let stderrText = stderr.finish(stderrPipe)

        if timedOut.isSet { throw ADBError.timeout }
        try Task.checkCancellation()

        return CommandResult(
            exitCode: process.terminationStatus,
            stdout: stdoutText,
            stderr: stderrText
        )
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

/// Accumulates pipe output on a background queue, capped at `limit` bytes.
private final class PipeBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private let limit: Int
    private var data = Data()
    private var truncated = false

    init(limit: Int) {
        self.limit = limit
    }

    func attach(_ pipe: Pipe) {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            self?.append(chunk)
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
        let (snapshot, wasTruncated) = lock.withLock { (data, truncated) }
        var text = String(decoding: snapshot, as: UTF8.self)
        if wasTruncated {
            text += "\n[output truncated at \(limit / 1024) KB]"
        }
        return text
    }

    private func append(_ chunk: Data) {
        lock.withLock {
            let remaining = limit - data.count
            guard remaining > 0 else {
                truncated = true
                return
            }
            if chunk.count > remaining {
                data.append(contentsOf: chunk.prefix(remaining))
                truncated = true
            } else {
                data.append(chunk)
            }
        }
    }
}
