import Foundation

extension BrewService {
    // MARK: - Diagnostics

    /// Run brew doctor with streaming output
    nonisolated func runDoctor() async -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                // Get brew path
                let pathResolver = BrewPathResolver()
                guard let brewPath = await pathResolver.resolve() else {
                    continuation.finish()
                    return
                }

                // Execute brew doctor with streaming
                let shell = ShellExecutor()
                let stream = await shell.executeWithStreaming("\(brewPath) doctor")
                for await line in stream {
                    continuation.yield(line)
                }
                continuation.finish()
            }
        }
    }

    /// Get disk usage information for Homebrew
    nonisolated func getDiskUsage() async throws -> DiskUsageInfo {
        let pathResolver = BrewPathResolver()
        guard let brewPath = await pathResolver.resolve() else {
            throw BrewError.brewNotInstalled
        }

        let shell = ShellExecutor()

        // Get cache path
        let cacheResult = try await shell.execute("\(brewPath) --cache")
        guard cacheResult.isSuccess else {
            throw BrewError.commandFailed(cacheResult.stderr)
        }
        let cachePath = cacheResult.trimmedOutput

        // Calculate cache size using du
        let duResult = try await shell.execute("du -sk '\(cachePath)'")
        var cacheSize: Int64 = 0
        if duResult.isSuccess {
            let components = duResult.trimmedOutput.components(separatedBy: .whitespaces)
            if let sizeKB = components.first, let size = Int64(sizeKB) {
                cacheSize = size * 1024
            }
        }

        // Get Cellar path (where formulae are installed)
        let cellarResult = try await shell.execute("\(brewPath) --cellar")
        var cellarSize: Int64 = 0
        if cellarResult.isSuccess {
            let cellarPath = cellarResult.trimmedOutput
            let cellarDuResult = try await shell.execute("du -sk '\(cellarPath)'")
            if cellarDuResult.isSuccess {
                let components = cellarDuResult.trimmedOutput.components(separatedBy: .whitespaces)
                if let sizeKB = components.first, let size = Int64(sizeKB) {
                    cellarSize = size * 1024
                }
            }
        }

        // Get Caskroom path
        let caskroomResult = try await shell.execute("\(brewPath) --caskroom")
        var caskroomSize: Int64 = 0
        if caskroomResult.isSuccess {
            let caskroomPath = caskroomResult.trimmedOutput
            let caskroomDuResult = try await shell.execute("du -sk '\(caskroomPath)'")
            if caskroomDuResult.isSuccess {
                let components = caskroomDuResult.trimmedOutput.components(separatedBy: .whitespaces)
                if let sizeKB = components.first, let size = Int64(sizeKB) {
                    caskroomSize = size * 1024
                }
            }
        }

        return DiskUsageInfo(
            cacheSize: cacheSize,
            cellarSize: cellarSize,
            caskroomSize: caskroomSize,
            totalSize: cacheSize + cellarSize + caskroomSize
        )
    }

    /// Get analytics status
    nonisolated func getAnalyticsStatus() async throws -> Bool {
        let pathResolver = BrewPathResolver()
        guard let brewPath = await pathResolver.resolve() else {
            throw BrewError.brewNotInstalled
        }

        let shell = ShellExecutor()
        let result = try await shell.execute("\(brewPath) analytics state")
        guard result.isSuccess else {
            throw BrewError.commandFailed(result.stderr)
        }

        let output = result.trimmedOutput.lowercased()
        return output.contains("enabled") || output.contains("on")
    }

    /// Set analytics on or off
    nonisolated func setAnalytics(enabled: Bool) async throws {
        let pathResolver = BrewPathResolver()
        guard let brewPath = await pathResolver.resolve() else {
            throw BrewError.brewNotInstalled
        }

        let shell = ShellExecutor()
        let action = enabled ? "on" : "off"
        let result = try await shell.execute("\(brewPath) analytics \(action)")
        guard result.isSuccess else {
            throw BrewError.commandFailed(result.stderr)
        }
    }

    /// Clear cache with streaming output
    nonisolated func clearCache() async -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                // Get brew path
                let pathResolver = BrewPathResolver()
                guard let brewPath = await pathResolver.resolve() else {
                    continuation.finish()
                    return
                }

                // Execute cleanup with streaming
                let shell = ShellExecutor()
                let stream = await shell.executeWithStreaming("\(brewPath) cleanup --prune=all -s")
                for await line in stream {
                    continuation.yield(line)
                }
                continuation.finish()
            }
        }
    }
}
