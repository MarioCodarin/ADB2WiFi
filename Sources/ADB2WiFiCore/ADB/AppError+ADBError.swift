extension AppError {
    /// Maps any error thrown by the ADB layer to user-facing guidance.
    init(mapping error: Error) {
        if let appError = error as? AppError {
            self = appError
            return
        }
        switch error {
        case ADBError.timeout:
            self = .timeout
        case ADBError.unauthorized:
            self = .authorizationPending
        case ADBError.missingExecutable:
            self = .missingADB
        case ADBError.launchFailed(let message):
            self = .adbLaunchFailed(message)
        case ADBError.unparseable(let output):
            self = .adbOutput(Self.truncated(output))
        case ADBError.nonZeroExit(let result):
            let message = [result.stderr, result.stdout].first { !$0.isEmpty } ?? "exit \(result.exitCode)"
            self = .adbOutput(Self.truncated(message))
        default:
            self = .adbOutput(Self.truncated(String(describing: error)))
        }
    }

    /// Keeps a raw ADB message from turning the popover into a wall of text.
    private static func truncated(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 400 else { return trimmed }
        return String(trimmed.prefix(400)) + "…"
    }
}
