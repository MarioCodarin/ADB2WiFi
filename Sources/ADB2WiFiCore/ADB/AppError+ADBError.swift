import Foundation

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
        case ADBError.unparseable(let output):
            self = .adbOutput(output)
        case ADBError.nonZeroExit(let result):
            let message = [result.stderr, result.stdout].first { !$0.isEmpty } ?? "exit \(result.exitCode)"
            self = .adbOutput(message)
        default:
            self = .adbOutput(String(describing: error))
        }
    }
}
