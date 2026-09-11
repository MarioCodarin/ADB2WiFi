import Foundation
import Testing
@testable import ADB2WiFiCore

@Test func timeoutTerminatesProcessAndThrows() async {
    let runner = ProcessCommandRunner()
    await #expect(throws: ADBError.self) {
        try await runner.run(
            executable: URL(fileURLWithPath: "/bin/sleep"),
            arguments: ["5"],
            timeout: .milliseconds(100)
        )
    }
}

@Test func timeoutCompletesWellBeforeChildWouldExit() async throws {
    let runner = ProcessCommandRunner()
    let start = ContinuousClock.now
    await #expect(throws: ADBError.timeout) {
        try await runner.run(
            executable: URL(fileURLWithPath: "/bin/sleep"),
            arguments: ["5"],
            timeout: .milliseconds(100)
        )
    }
    let elapsed = ContinuousClock.now - start
    #expect(elapsed < .seconds(2))
}

@Test func capturesStdoutAndZeroExit() async throws {
    let runner = ProcessCommandRunner()
    let result = try await runner.run(
        executable: URL(fileURLWithPath: "/bin/echo"),
        arguments: ["hello-adb"],
        timeout: .seconds(2)
    )
    #expect(result.exitCode == 0)
    #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "hello-adb")
    #expect(result.stderr.isEmpty)
}

@Test func returnsNonZeroExitWithoutThrowing() async throws {
    let runner = ProcessCommandRunner()
    let result = try await runner.run(
        executable: URL(fileURLWithPath: "/usr/bin/false"),
        arguments: [],
        timeout: .seconds(2)
    )
    #expect(result.exitCode != 0)
}
