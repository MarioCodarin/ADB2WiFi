import Foundation
import Observation

/// Key-value storage used by `AppSettings`. `UserDefaults` is the default; tests inject a memory-backed type.
public protocol DefaultsStorage: AnyObject {
    func string(forKey defaultName: String) -> String?
    func integer(forKey defaultName: String) -> Int
    func object(forKey defaultName: String) -> Any?
    func set(_ value: Any?, forKey defaultName: String)
}

extension DefaultsStorage {
    public func integer(forKey defaultName: String) -> Int { 0 }
}

extension UserDefaults: DefaultsStorage {}

@MainActor
@Observable
public final class AppSettings {
    public static let adbPathOverrideKey = "adbPathOverride"
    public static let portKey = "adbPort"
    public static let autoReconnectKey = "autoReconnect"
    public static let rememberedEndpointsKey = "rememberedEndpoints"

    private static let rememberedLimit = 20

    @ObservationIgnored
    private let storage: any DefaultsStorage

    public var adbPathOverride: URL? {
        didSet {
            guard adbPathOverride != oldValue else { return }
            storage.set(adbPathOverride?.path, forKey: Self.adbPathOverrideKey)
            Log.settings.notice("adb path override changed to=\(self.adbPathOverride?.path ?? "auto", privacy: .private)")
        }
    }

    /// Port used for `adb tcpip` and the generated endpoint. Always in `1...65535`.
    public var port: Int {
        didSet {
            let clamped = Self.clamp(port)
            if port != clamped {
                port = clamped
                storage.set(clamped, forKey: Self.portKey)
                return
            }
            guard port != oldValue else { return }
            storage.set(port, forKey: Self.portKey)
            Log.settings.notice("adb port changed to=\(self.port, privacy: .public)")
        }
    }

    /// Try the last verified endpoint when the app launches or wakes.
    public var autoReconnect: Bool {
        didSet {
            guard autoReconnect != oldValue else { return }
            storage.set(autoReconnect, forKey: Self.autoReconnectKey)
            Log.settings.notice("auto reconnect=\(self.autoReconnect, privacy: .public)")
        }
    }

    /// Local serial -> last verified `ip:port`. Used only for opt-out auto-reconnect.
    public private(set) var rememberedEndpoints: [String: String]

    public init(storage: any DefaultsStorage = UserDefaults.standard) {
        self.storage = storage
        if let path = storage.string(forKey: Self.adbPathOverrideKey), !path.isEmpty {
            adbPathOverride = URL(fileURLWithPath: path)
        }
        let storedPort = storage.integer(forKey: Self.portKey)
        port = Self.clamp(storedPort == 0 ? Endpoint.defaultPort : storedPort)
        autoReconnect = (storage.object(forKey: Self.autoReconnectKey) as? Bool) ?? true
        rememberedEndpoints = Self.loadRemembered(from: storage)
    }

    public func resetADBPath() {
        adbPathOverride = nil
    }

    public func rememberedEndpoint(for serialNo: String) -> String? {
        rememberedEndpoints[serialNo]
    }

    public func remember(endpoint: String, for serialNo: String) {
        guard !serialNo.isEmpty, !endpoint.isEmpty else { return }
        rememberedEndpoints[serialNo] = endpoint
        while rememberedEndpoints.count > Self.rememberedLimit,
              let oldest = rememberedEndpoints.keys.first(where: { $0 != serialNo }) {
            rememberedEndpoints.removeValue(forKey: oldest)
        }
        persistRemembered()
        Log.settings.notice("remembered endpoint device=\(serialNo, privacy: .private)")
    }

    public func forgetEndpoint(for serialNo: String) {
        guard rememberedEndpoints.removeValue(forKey: serialNo) != nil else { return }
        persistRemembered()
        Log.settings.notice("forgot endpoint device=\(serialNo, privacy: .private)")
    }

    public func clearRememberedEndpoints() {
        guard !rememberedEndpoints.isEmpty else { return }
        rememberedEndpoints.removeAll(keepingCapacity: true)
        persistRemembered()
        Log.settings.notice("cleared remembered endpoints")
    }

    private func persistRemembered() {
        guard !rememberedEndpoints.isEmpty else {
            storage.set(nil, forKey: Self.rememberedEndpointsKey)
            return
        }
        guard let data = try? JSONEncoder().encode(rememberedEndpoints),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        storage.set(json, forKey: Self.rememberedEndpointsKey)
    }

    private static func loadRemembered(from storage: any DefaultsStorage) -> [String: String] {
        guard let json = storage.string(forKey: rememberedEndpointsKey),
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func clamp(_ port: Int) -> Int {
        min(max(port, 1), 65535)
    }
}
