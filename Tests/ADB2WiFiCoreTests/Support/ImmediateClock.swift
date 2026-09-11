import Foundation
@testable import ADB2WiFiCore

struct ImmediateClock: Sleeping {
    func sleep(for duration: Duration) async throws {
        try Task.checkCancellation()
    }
}
