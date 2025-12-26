import Foundation

/// Custom error types for shell execution
enum ShellError: LocalizedError {
    case commandNotFound(String)
    case executionFailed(exitCode: Int32, stderr: String)
    case timeout
    case cancelled
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .commandNotFound(let command):
            return "Command not found: \(command)"
        case .executionFailed(let exitCode, let stderr):
            return "Command failed with exit code \(exitCode): \(stderr)"
        case .timeout:
            return "Command timed out"
        case .cancelled:
            return "Command was cancelled"
        case .invalidOutput:
            return "Invalid or unexpected command output"
        }
    }
}

/// Result of a shell command execution
struct ShellResult: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32

    var isSuccess: Bool {
        exitCode == 0
    }

    var trimmedOutput: String {
        stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Utility for executing shell commands asynchronously
final class ShellExecutor: Sendable {

    /// Execute a shell command and return the result
    func execute(_ command: String, arguments: [String] = [], environment: [String: String]? = nil) async throws -> ShellResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-c", "\(command) \(arguments.joined(separator: " "))"]
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                // Set up environment
                var env = ProcessInfo.processInfo.environment

                // Add system proxy settings
                let proxyEnv = ProxyManager.shared.getProxyEnvironment()
                env.merge(proxyEnv) { _, new in new }

                if let customEnv = environment {
                    env.merge(customEnv) { _, new in new }
                }
                // Ensure brew is in PATH for both Apple Silicon and Intel Macs
                let brewPaths = "/opt/homebrew/bin:/usr/local/bin"
                if let existingPath = env["PATH"] {
                    env["PATH"] = "\(brewPaths):\(existingPath)"
                } else {
                    env["PATH"] = brewPaths
                }
                process.environment = env

                // Collect output data
                var stdoutData = Data()
                var stderrData = Data()
                let stdoutLock = NSLock()
                let stderrLock = NSLock()

                // Read stdout asynchronously to prevent buffer deadlock
                stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        stdoutLock.lock()
                        stdoutData.append(data)
                        stdoutLock.unlock()
                    }
                }

                // Read stderr asynchronously
                stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        stderrLock.lock()
                        stderrData.append(data)
                        stderrLock.unlock()
                    }
                }

                do {
                    try process.run()
                    process.waitUntilExit()

                    // Clean up handlers
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil

                    // Read any remaining data
                    stdoutLock.lock()
                    let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    stdoutData.append(remainingStdout)
                    stdoutLock.unlock()

                    stderrLock.lock()
                    let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    stderrData.append(remainingStderr)
                    stderrLock.unlock()

                    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                    let result = ShellResult(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus)
                    continuation.resume(returning: result)
                } catch {
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Execute a command and stream output line by line
    func executeWithStreaming(_ command: String, arguments: [String] = []) -> AsyncStream<String> {
        AsyncStream { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let stdoutPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-c", "\(command) \(arguments.joined(separator: " "))"]
                process.standardOutput = stdoutPipe
                process.standardError = stdoutPipe // Combine stdout and stderr

                // Set up environment with brew paths and proxy
                var env = ProcessInfo.processInfo.environment

                // Add system proxy settings
                let proxyEnv = ProxyManager.shared.getProxyEnvironment()
                env.merge(proxyEnv) { _, new in new }

                let brewPaths = "/opt/homebrew/bin:/usr/local/bin"
                if let existingPath = env["PATH"] {
                    env["PATH"] = "\(brewPaths):\(existingPath)"
                } else {
                    env["PATH"] = brewPaths
                }
                process.environment = env

                let handle = stdoutPipe.fileHandleForReading

                // Read output as it comes
                handle.readabilityHandler = { fileHandle in
                    let data = fileHandle.availableData
                    if data.isEmpty {
                        return
                    }
                    if let output = String(data: data, encoding: .utf8) {
                        continuation.yield(output)
                    }
                }

                do {
                    try process.run()
                    process.waitUntilExit()
                    handle.readabilityHandler = nil
                    continuation.finish()
                } catch {
                    handle.readabilityHandler = nil
                    continuation.finish()
                }
            }
        }
    }
}
