import Foundation

/// A remembered phone that is not necessarily present in `adb devices` right now.
public struct RememberedDevice: Identifiable, Equatable, Sendable {
    public var identity: DeviceIdentity
    public var endpoint: String
    public var model: String
    public var lastConnected: Date

    public var id: DeviceIdentity { identity }

    public init(identity: DeviceIdentity, endpoint: String, model: String, lastConnected: Date) {
        self.identity = identity
        self.endpoint = endpoint
        self.model = model
        self.lastConnected = lastConnected
    }
}
