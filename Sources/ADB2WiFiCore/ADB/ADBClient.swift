import Foundation

public struct ADBClient: Sendable {
    private static let defaultTimeout: Duration = .seconds(8)

    private let executable: URL
    private let runner: any CommandRunning

    public init(executable: URL, runner: any CommandRunning) {
        self.executable = executable
        self.runner = runner
    }

    public func version() async throws -> String {
        let result = try await invoke(["version"])
        try requireZero(result)
        guard let version = Self.parseVersion(result.stdout) else {
            throw ADBError.unparseable(result.stdout)
        }
        return version
    }

    public func devices() async throws -> [ADBTransport] {
        let result = try await invoke(["devices", "-l"])
        try requireZero(result)
        return DeviceListParser.parse(result.stdout)
    }

    public func tcpip(serial: String, port: Int = Endpoint.defaultPort) async throws {
        let result = try await invoke(["-s", serial, "tcpip", String(port)])
        try requireZero(result)
    }

    /// Succeeds only if stdout matches `(already )?connected to `. Exit code 0 is not trusted.
    public func connect(endpoint: String, timeout: Duration = .seconds(8)) async throws {
        let result = try await invoke(["connect", endpoint], timeout: timeout)
        if Self.isConnectSuccess(result.stdout) { return }
        throw ADBError.unparseable(result.stdout)
    }

    public func disconnect(endpoint: String) async throws {
        let result = try await invoke(["disconnect", endpoint])
        try requireZero(result)
    }

    public func shell(serial: String, command: String) async throws -> String {
        let result = try await invoke(["-s", serial, "shell", command])
        try requireZero(result)
        return result.stdout
    }

    public func serialNo(serial: String) async throws -> String {
        try await shell(serial: serial, command: "getprop ro.serialno")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func model(serial: String) async throws -> String {
        try await shell(serial: serial, command: "getprop ro.product.model")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func wifiAddresses(serial: String) async throws -> [WiFiAddress] {
        let stdout = try await shell(serial: serial, command: "ip -o -4 addr show up")
        return WiFiAddressParser.parse(stdout)
    }

    private func invoke(_ arguments: [String], timeout: Duration = defaultTimeout) async throws -> CommandResult {
        let verb = Self.verb(arguments)
        let target = Self.target(arguments)
        let started = ContinuousClock.now
        Log.adb.debug(
            "exec verb=\(verb, privacy: .public) target=\(target, privacy: .private) timeout=\(timeout.inMilliseconds, privacy: .public)ms"
        )

        do {
            let result = try await runner.run(executable: executable, arguments: arguments, timeout: timeout)
            let elapsed = (ContinuousClock.now - started).inMilliseconds
            Log.adb.debug(
                "exit verb=\(verb, privacy: .public) code=\(result.exitCode, privacy: .public) duration=\(elapsed, privacy: .public)ms"
            )
            if arguments.first == "-s" {
                let haystack = result.stdout + "\n" + result.stderr
                if haystack.range(of: "unauthorized", options: .caseInsensitive) != nil {
                    throw ADBError.unauthorized
                }
            }
            return result
        } catch {
            let elapsed = (ContinuousClock.now - started).inMilliseconds
            Log.adb.error(
                "failed verb=\(verb, privacy: .public) duration=\(elapsed, privacy: .public)ms error=\(String(describing: error), privacy: .private)"
            )
            throw error
        }
    }

    private func requireZero(_ result: CommandResult) throws {
        if result.exitCode != 0 {
            throw ADBError.nonZeroExit(result)
        }
    }

    private static func verb(_ arguments: [String]) -> String {
        arguments.first == "-s" ? (arguments.count > 2 ? arguments[2] : "shell") : arguments.first ?? "adb"
    }

    private static func target(_ arguments: [String]) -> String {
        if arguments.first == "-s", arguments.count > 1 { return arguments[1] }
        if arguments.first == "connect" || arguments.first == "disconnect", arguments.count > 1 {
            return arguments[1]
        }
        return "-"
    }

    private static func isConnectSuccess(_ stdout: String) -> Bool {
        stdout.range(of: #"(already )?connected to "#, options: .regularExpression) != nil
    }

    /// Prefer the Platform Tools `Version 37.0.1` line; fall back to the ADB protocol line.
    private static func parseVersion(_ stdout: String) -> String? {
        let protocolMarker = "Android Debug Bridge version "
        let platformToolsMarker = "Version "
        var protocolVersion: String?
        for line in stdout.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(platformToolsMarker) {
                let version = trimmed.dropFirst(platformToolsMarker.count)
                    .prefix(while: { $0.isNumber || $0 == "." })
                if !version.isEmpty { return String(version) }
            }
            if trimmed.hasPrefix(protocolMarker) {
                let version = trimmed.dropFirst(protocolMarker.count)
                    .prefix(while: { $0.isNumber || $0 == "." })
                if !version.isEmpty { protocolVersion = String(version) }
            }
        }
        return protocolVersion
    }
}
