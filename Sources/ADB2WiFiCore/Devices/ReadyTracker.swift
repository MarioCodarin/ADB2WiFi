/// Tracks which devices have crossed into `readyToUnplug` so a notification is posted
/// once per successful connection, not on every poll.
public struct ReadyTracker: Sendable {
    private var ready: Set<DeviceIdentity> = []

    public init() {}

    /// Returns devices that are ready now and were not ready on the previous update.
    public mutating func newlyReady(in devices: [Device]) -> [Device] {
        let current = devices.filter { device in
            if case .readyToUnplug = device.operation { return true }
            return false
        }
        let identifiers = Set(current.map(\.identity))
        let newly = current.filter { !ready.contains($0.identity) }
        ready = identifiers
        return newly
    }
}
