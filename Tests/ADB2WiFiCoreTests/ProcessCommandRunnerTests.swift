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

@Test func capsVeryLargeOutput() async throws {
    let runner = ProcessCommandRunner()
    let result = try await runner.run(
        executable: URL(fileURLWithPath: "/usr/bin/seq"),
        arguments: ["1", "200000"],
        timeout: .seconds(5)
    )
    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("[output truncated at 256 KB]"))
    #expect(result.stdout.utf8.count < 300_000)
}

@Test func capturesStdoutAcrossRepeatedRuns() async throws {
    let runner = ProcessCommandRunner()
    for index in 0..<20 {
        let result = try await runner.run(
            executable: URL(fileURLWithPath: "/bin/echo"),
            arguments: ["run-\(index)"],
            timeout: .seconds(2)
        )
        let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(output == "run-\(index)")
    }
}
