import Foundation

/// Resolves the Homebrew installation path on the system
actor BrewPathResolver {
    /// Cached brew path
    private var cachedPath: String?
    private var hasChecked = false

    /// Standard Homebrew installation paths
    private let knownPaths = [
        "/opt/homebrew/bin/brew",    // Apple Silicon
        "/usr/local/bin/brew"         // Intel
    ]

    /// Resolves and returns the path to the brew executable, or nil if not installed
    func resolve() async -> String? {
        if hasChecked {
            return cachedPath
        }

        // Check known paths first (faster)
        for path in knownPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                cachedPath = path
                hasChecked = true
                return path
            }
        }

        // Fall back to which command
        if let path = await findBrewUsingWhich() {
            cachedPath = path
            hasChecked = true
            return path
        }

        hasChecked = true
        return nil
    }

    /// Use `which` to find brew in PATH
    private func findBrewUsingWhich() async -> String? {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["brew"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {
            // Silently fail and return nil
        }

        return nil
    }

    /// Force a re-check of the brew path (useful after installation)
    func invalidateCache() {
        cachedPath = nil
        hasChecked = false
    }

    /// Check if Homebrew is installed without caching
    func isBrewInstalled() async -> Bool {
        await resolve() != nil
    }

    /// Get the Homebrew prefix directory
    func getBrewPrefix() async -> String? {
        guard let brewPath = await resolve() else { return nil }

        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = ["--prefix"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let prefix = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    return prefix
                }
            }
        } catch {
            // Fall back to inferring from brew path
        }

        // Infer prefix from brew path
        if brewPath.hasPrefix("/opt/homebrew") {
            return "/opt/homebrew"
        } else if brewPath.hasPrefix("/usr/local") {
            return "/usr/local"
        }

        return nil
    }

    /// Get Homebrew version
    func getBrewVersion() async -> String? {
        guard let brewPath = await resolve() else { return nil }

        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = ["--version"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let version = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    // Extract just the version number from "Homebrew 4.x.x"
                    let components = version.components(separatedBy: "\n")
                    if let firstLine = components.first {
                        return firstLine.replacingOccurrences(of: "Homebrew ", with: "")
                    }
                    return version
                }
            }
        } catch {
            // Silently fail
        }

        return nil
    }
}
