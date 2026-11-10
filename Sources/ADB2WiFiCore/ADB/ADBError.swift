public enum ADBError: Error, Equatable, Sendable {
    case missingExecutable
    case launchFailed(String)
    case timeout
    case nonZeroExit(CommandResult)
    case unparseable(String)
    case unauthorized
}
