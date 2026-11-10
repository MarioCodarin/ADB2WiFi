import Foundation

/// Persisted metadata for a phone we connected successfully before.
public struct RememberedConnection: Codable, Equatable, Sendable {
    public var endpoint: String
    public var model: String
    public var lastConnected: Date

    public init(endpoint: String, model: String = "", lastConnected: Date = Date()) {
        self.endpoint = endpoint
        self.model = model
        self.lastConnected = lastConnected
    }
}
