import Foundation
import Observation

/// Key-value storage used by `AppSettings`. `UserDefaults` is the default; tests inject a memory-backed type.
public protocol DefaultsStorage: AnyObject {
    func string(forKey defaultName: String) -> String?
    func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: DefaultsStorage {}

@Observable
public final class AppSettings {
    public static let adbPathOverrideKey = "adbPathOverride"

    @ObservationIgnored
    private let storage: any DefaultsStorage

    public var adbPathOverride: URL? {
        didSet { persistOverride() }
    }

    public init(storage: any DefaultsStorage = UserDefaults.standard) {
        self.storage = storage
        if let path = storage.string(forKey: Self.adbPathOverrideKey), !path.isEmpty {
            adbPathOverride = URL(fileURLWithPath: path)
        }
    }

    private func persistOverride() {
        storage.set(adbPathOverride?.path, forKey: Self.adbPathOverrideKey)
    }
}
