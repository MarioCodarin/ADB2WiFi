import Foundation
import Observation

/// Key-value storage used by `AppSettings`. `UserDefaults` is the default; tests inject a memory-backed type.
public protocol DefaultsStorage: AnyObject {
    func string(forKey defaultName: String) -> String?
    func integer(forKey defaultName: String) -> Int
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

    public init(storage: any DefaultsStorage = UserDefaults.standard) {
        self.storage = storage
        if let path = storage.string(forKey: Self.adbPathOverrideKey), !path.isEmpty {
            adbPathOverride = URL(fileURLWithPath: path)
        }
        let storedPort = storage.integer(forKey: Self.portKey)
        port = Self.clamp(storedPort == 0 ? Endpoint.defaultPort : storedPort)
    }

    public func resetADBPath() {
        adbPathOverride = nil
    }

    private static func clamp(_ port: Int) -> Int {
        min(max(port, 1), 65535)
    }
}
