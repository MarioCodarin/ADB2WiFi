import Foundation
@testable import ADB2WiFiCore

final class InMemoryDefaults: DefaultsStorage {
    private var values: [String: Any] = [:]

    func string(forKey defaultName: String) -> String? {
        values[defaultName] as? String
    }

    func integer(forKey defaultName: String) -> Int {
        values[defaultName] as? Int ?? 0
    }

    func object(forKey defaultName: String) -> Any? {
        values[defaultName]
    }

    func set(_ value: Any?, forKey defaultName: String) {
        if let value {
            values[defaultName] = value
        } else {
            values.removeValue(forKey: defaultName)
        }
    }
}
