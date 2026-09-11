public enum ADBError: Error, Equatable, Sendable {
    case missingExecutable
    case timeout
    case nonZeroExit(CommandResult)
    case unparseable(String)
}
