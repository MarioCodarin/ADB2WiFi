import Foundation
@testable import ADB2WiFiCore

struct FakeCommandRunner: CommandRunning {
    struct Call: Equatable, Sendable {
        var executable: URL
        var arguments: [String]
        var timeout: Duration
    }

    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var calls: [Call] = []
        var handlers: [@Sendable ([String]) async throws -> CommandResult] = []
        var fallback: (@Sendable ([String]) async throws -> CommandResult)?
        var nextHandler = 0
    }

    private let state = State()

    var handlers: [@Sendable ([String]) async throws -> CommandResult] {
        get { state.lock.withLock { state.handlers } }
        nonmutating set { state.lock.withLock { state.handlers = newValue } }
    }

    var calls: [Call] {
        state.lock.withLock { state.calls }
    }

    var invokedCommands: [[String]] {
        calls.map(\.arguments)
    }

    var tcpipSerials: [String] {
        calls.compactMap { call in
            let args = call.arguments
            guard args.count >= 3, args[0] == "-s", args[2] == "tcpip" else { return nil }
            return args[1]
        }
    }

    var tcpipCount: Int { tcpipSerials.count }

    var disconnectEndpoints: [String] {
        calls.compactMap { call in
            let args = call.arguments
            guard args.count >= 2, args[0] == "disconnect" else { return nil }
            return args[1]
        }
    }

    var fallback: (@Sendable ([String]) async throws -> CommandResult)? {
        get { state.lock.withLock { state.fallback } }
        nonmutating set { state.lock.withLock { state.fallback = newValue } }
    }

    var connectEndpoints: [String] {
        calls.compactMap { call in
            let args = call.arguments
            guard args.count >= 2, args[0] == "connect" else { return nil }
            return args[1]
        }
    }

    var targetedSerials: [String] {
        calls.compactMap { call in
            let args = call.arguments
            if args.count >= 2, args[0] == "-s" { return args[1] }
            if args.count >= 2, args[0] == "connect" { return args[1] }
            return nil
        }
    }

    init(handlers: [@Sendable ([String]) async throws -> CommandResult] = []) {
        state.handlers = handlers
    }

    func clearCalls() {
        state.lock.withLock { state.calls.removeAll() }
    }

    func run(executable: URL, arguments: [String], timeout: Duration) async throws -> CommandResult {
        let (handler, fallback) = dequeueHandler(executable: executable, arguments: arguments, timeout: timeout)
        if let handler {
            return try await handler(arguments)
        }
        if let fallback {
            return try await fallback(arguments)
        }
        return CommandResult(exitCode: 0, stdout: "", stderr: "")
    }

    private func dequeueHandler(
        executable: URL,
        arguments: [String],
        timeout: Duration
    ) -> (
        (@Sendable ([String]) async throws -> CommandResult)?,
        (@Sendable ([String]) async throws -> CommandResult)?
    ) {
        state.lock.withLock {
            state.calls.append(Call(executable: executable, arguments: arguments, timeout: timeout))
            if state.nextHandler < state.handlers.count {
                let handler = state.handlers[state.nextHandler]
                state.nextHandler += 1
                return (handler, nil)
            }
            return (nil, state.fallback)
        }
    }
}
