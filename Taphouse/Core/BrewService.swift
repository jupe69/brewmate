import Foundation

/// Protocol defining Homebrew service operations
protocol BrewServiceProtocol: Sendable {
    func getInstalledFormulae() async throws -> [Formula]
    func getInstalledCasks() async throws -> [Cask]
    func search(query: String) async throws -> SearchResults
    func getFormulaInfo(name: String) async throws -> Formula
    func getCaskInfo(name: String) async throws -> Cask
    func install(packageName: String, isCask: Bool) async -> AsyncStream<String>
    func uninstall(packageName: String, isCask: Bool) async throws
    func upgrade(packageName: String?) async -> AsyncStream<String>
    func getOutdated() async throws -> [OutdatedPackage]
    func cleanup(dryRun: Bool) async throws -> CleanupResult
    func doctor() async throws -> [DiagnosticIssue]
    func getServices() async throws -> [BrewServiceInfo]
    func controlService(name: String, action: ServiceAction) async throws
    func updateBrewData() async throws
    func getDependencyTree(packageName: String) async throws -> DependencyTree
    func getDependents(packageName: String) async throws -> [String]
    func exportBrewfile() async throws -> String
    func importBrewfile(content: String) async -> AsyncStream<String>
    func importBrewfileFromPath(path: String) async -> AsyncStream<String>
    func installMultiple(packages: [String], areCasks: Bool) async -> AsyncStream<String>
    func uninstallMultiple(packages: [String], areCasks: Bool) async -> AsyncStream<String>
    func upgradeMultiple(packages: [String]) async -> AsyncStream<String>
    func getPinnedPackages() async throws -> [String]
    func pinPackage(name: String) async throws
    func unpinPackage(name: String) async throws
    func getQuarantinedApps() async throws -> [QuarantinedApp]
    func removeQuarantine(appPath: String) async throws
    func getCaskInstallPath(caskName: String) async throws -> String?
    func getTaps() async throws -> [TapInfo]
    func addTap(name: String) async throws
    func removeTap(name: String) async throws
    func getTapInfo(name: String) async throws -> TapInfo

    // MAS (Mac App Store) operations
    func isMASInstalled() async -> Bool
    func getInstalledMASApps() async throws -> [MASApp]
    func getOutdatedMASApps() async throws -> [OutdatedMASApp]
    func searchMAS(query: String) async throws -> [MASSearchResult]
    func installMASApp(id: Int) async -> AsyncStream<String>
    func upgradeMASApps() async -> AsyncStream<String>
    func uninstallMASApp(id: Int) async -> AsyncStream<String>

    // Package analysis
    func getLeafPackages() async throws -> Set<String>
}

/// Main service class for interacting with Homebrew CLI
actor BrewService: BrewServiceProtocol {
    private let shell: ShellExecutor
    private let pathResolver: BrewPathResolver
    private var brewPath: String?

    init(shell: ShellExecutor = ShellExecutor(), pathResolver: BrewPathResolver = BrewPathResolver()) {
        self.shell = shell
        self.pathResolver = pathResolver
    }

    /// Ensures brew path is resolved and returns it
    private func getBrewPath() async throws -> String {
        if let path = brewPath {
            return path
        }
        guard let path = await pathResolver.resolve() else {
            throw BrewError.brewNotInstalled
        }
        brewPath = path
        return path
    }

    /// Execute a brew command
    private func brew(_ arguments: String...) async throws -> ShellResult {
        let path = try await getBrewPath()
        let command = "\(path) \(arguments.joined(separator: " "))"
        return try await shell.execute(command)
    }

    /// Execute a brew command with streaming output
    private func brewStream(_ arguments: String...) async -> AsyncStream<String> {
        guard let path = try? await getBrewPath() else {
            return AsyncStream { $0.finish() }
        }
        let command = "\(path) \(arguments.joined(separator: " "))"
        return await shell.executeWithStreaming(command)
    }

    // MARK: - Formulae

    func getInstalledFormulae() async throws -> [Formula] {
        let result = try await brew("info", "--installed", "--json=v2")

        guard result.isSuccess else {
            throw BrewError.commandFailed(result.stderr)
        }

        guard let data = result.stdout.data(using: .utf8) else {
            throw BrewError.invalidOutput
        }

        let decoder = JSONDecoder()
        let response = try decoder.decode(BrewInfoResponse.self, from: data)
        return response.formulae.map { $0.toFormula() }
    }

    // MARK: - Casks

    func getInstalledCasks() async throws -> [Cask] {
        let result = try await brew("info", "--installed", "--cask", "--json=v2")

        // If no casks installed, brew may return empty or error
        if result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
           result.stdout.contains("No casks to list") {
            return []
        }

        guard result.isSuccess else {
            throw BrewError.commandFailed(result.stderr)
        }

        guard let data = result.stdout.data(using: .utf8) else {
            throw BrewError.invalidOutput
        }

        let decoder = JSONDecoder()
        let response = try decoder.decode(BrewInfoResponse.self, from: data)
        return response.casks.map { $0.toCask() }
    }

    // MARK: - Search

    func search(query: String) async throws -> SearchResults {
        guard !query.isEmpty else {
            return SearchResults(formulae: [], casks: [])
        }

        let result = try await brew("search", "--formulae", "--casks", query)

        guard result.isSuccess else {
            throw BrewError.commandFailed(result.stderr)
        }

        var formulae: [String] = []
        var casks: [String] = []
        var isInCasks = false

        for line in result.stdout.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("==> Formulae") {
                isInCasks = false
                continue
            } else if trimmed.hasPrefix("==> Casks") {
                isInCasks = true
                continue
            } else if trimmed.hasPrefix("==>") {
                continue
            }

            if isInCasks {
                casks.append(contentsOf: trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty })
            } else {
                formulae.append(contentsOf: trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty })
            }
        }

        return SearchResults(formulae: formulae, casks: casks)
    }

    // MARK: - Package Info

    func getFormulaInfo(name: String) async throws -> Formula {
        let result = try await brew("info", "--json=v2", name)

        guard result.isSuccess else {
            throw BrewError.packageNotFound(name)
        }

        guard let data = result.stdout.data(using: .utf8) else {
            throw BrewError.invalidOutput
        }

        let decoder = JSONDecoder()
        let response = try decoder.decode(BrewInfoResponse.self, from: data)

        guard let formulaInfo = response.formulae.first else {
            throw BrewError.packageNotFound(name)
        }

        return formulaInfo.toFormula()
    }

    func getCaskInfo(name: String) async throws -> Cask {
        let result = try await brew("info", "--cask", "--json=v2", name)

        guard result.isSuccess else {
            throw BrewError.packageNotFound(name)
        }

        guard let data = result.stdout.data(using: .utf8) else {
            throw BrewError.invalidOutput
        }

        let decoder = JSONDecoder()
        let response = try decoder.decode(BrewInfoResponse.self, from: data)

        guard let caskInfo = response.casks.first else {
            throw BrewError.packageNotFound(name)
        }

        return caskInfo.toCask()
    }

    // MARK: - Install / Uninstall

    func install(packageName: String, isCask: Bool) async -> AsyncStream<String> {
        let args = isCask ? ["install", "--cask", packageName] : ["install", packageName]
        return await brewStream(args.joined(separator: " "))
    }

    func uninstall(packageName: String, isCask: Bool) async throws {
        let result: ShellResult
        if isCask {
            result = try await brew("uninstall", "--cask", packageName)
        } else {
            result = try await brew("uninstall", packageName)
        }

        guard result.isSuccess else {
            throw BrewError.commandFailed(result.stderr)
        }
    }

    // MARK: - Upgrade

    func upgrade(packageName: String?) async -> AsyncStream<String> {
        if let name = packageName {
            return await brewStream("upgrade", name)
        } else {
            return await brewStream("upgrade")
        }
    }

    // MARK: - Pin / Unpin

    func pin(packageName: String) async throws {
        let result = try await brew("pin", packageName)
        guard result.isSuccess else {
            throw BrewError.commandFailed(result.stderr)
        }
    }

    func unpin(packageName: String) async throws {
        let result = try await brew("unpin", packageName)
        guard result.isSuccess else {
            throw BrewError.commandFailed(result.stderr)
        }
    }

    // MARK: - Reinstall

    func reinstall(packageName: String, isCask: Bool) async -> AsyncStream<String> {
        let args = isCask ? ["reinstall", "--cask", packageName] : ["reinstall", packageName]
        return await brewStream(args.joined(separator: " "))
    }

    func getOutdated() async throws -> [OutdatedPackage] {
        let result = try await brew("outdated", "--json=v2")

        guard result.isSuccess else {
            throw BrewError.commandFailed(result.stderr)
        }

        guard let data = result.stdout.data(using: .utf8) else {
            throw BrewError.invalidOutput
        }

        let decoder = JSONDecoder()
        let response = try decoder.decode(OutdatedResponse.self, from: data)

        var packages: [OutdatedPackage] = []

        for formula in response.formulae {
            packages.append(OutdatedPackage(
                name: formula.name,
                installedVersion: formula.installedVersions.first ?? "unknown",
                currentVersion: formula.currentVersion,
                isCask: false,
                pinned: formula.pinned
            ))
        }

        for cask in response.casks {
            packages.append(OutdatedPackage(
                name: cask.name,
                installedVersion: cask.installedVersions.first ?? "unknown",
                currentVersion: cask.currentVersion,
                isCask: true
            ))
        }

        return packages
    }

    // MARK: - Bulk Operations

    func installMultiple(packages: [String], areCasks: Bool) async -> AsyncStream<String> {
        return AsyncStream { continuation in
            Task {
                for package in packages {
                    continuation.yield("==> Installing \(package)...")
                    let stream = await self.install(packageName: package, isCask: areCasks)
                    for await line in stream {
                        continuation.yield(line)
                    }
                }
                continuation.finish()
            }
        }
    }

    func uninstallMultiple(packages: [String], areCasks: Bool) async -> AsyncStream<String> {
        return AsyncStream { continuation in
            Task {
                for package in packages {
                    continuation.yield("==> Uninstalling \(package)...")
                    do {
                        try await self.uninstall(packageName: package, isCask: areCasks)
                        continuation.yield("Successfully uninstalled \(package)")
                    } catch {
                        continuation.yield("Error uninstalling \(package): \(error.localizedDescription)")
                    }
                }
                continuation.finish()
            }
        }
    }

    func upgradeMultiple(packages: [String]) async -> AsyncStream<String> {
        return AsyncStream { continuation in
            Task {
                for package in packages {
                    continuation.yield("==> Upgrading \(package)...")
                    let stream = await self.upgrade(packageName: package)
                    for await line in stream {
                        continuation.yield(line)
                    }
                }
                continuation.finish()
            }
        }
    }

    // MARK: - Cleanup

    func cleanup(dryRun: Bool) async throws -> CleanupResult {
        let args = dryRun ? ["cleanup", "--dry-run"] : ["cleanup"]
        let result = try await brew(args.joined(separator: " "))

        guard result.isSuccess || result.exitCode == 0 else {
            throw BrewError.commandFailed(result.stderr)
        }

        // Parse cleanup output
        var bytesFreed: Int64 = 0
        var formulaeRemoved: [String] = []
        var casksRemoved: [String] = []
        var downloadsCleaned = 0

        for line in result.stdout.components(separatedBy: .newlines) {
            if line.contains("Removing:") {
                if line.contains(".rb") || line.contains("Cellar") {
                    if let name = extractPackageName(from: line) {
                        formulaeRemoved.append(name)
                    }
                } else if line.contains("Caskroom") {
                    if let name = extractPackageName(from: line) {
                        casksRemoved.append(name)
                    }
                }
            } else if line.contains("downloads") {
                downloadsCleaned += 1
            } else if line.contains("freed") {
                if let bytes = extractBytes(from: line) {
                    bytesFreed = bytes
                }
            }
        }

        return CleanupResult(
            bytesFreed: bytesFreed,
            formulaeRemoved: formulaeRemoved,
            casksRemoved: casksRemoved,
            downloadsCleaned: downloadsCleaned
        )
    }

    // MARK: - Doctor

    func doctor() async throws -> [DiagnosticIssue] {
        let result = try await brew("doctor")

        var issues: [DiagnosticIssue] = []
        var currentCategory = ""

        for line in result.stdout.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("Warning:") {
                currentCategory = trimmed.replacingOccurrences(of: "Warning: ", with: "")
            } else if trimmed.hasPrefix("Error:") {
                issues.append(DiagnosticIssue(
                    category: "Error",
                    message: trimmed.replacingOccurrences(of: "Error: ", with: ""),
                    severity: .error
                ))
            } else if !currentCategory.isEmpty && !trimmed.hasPrefix("Please") {
                issues.append(DiagnosticIssue(
                    category: currentCategory,
                    message: trimmed,
                    severity: .warning
                ))
            }
        }

        return issues
    }

    // MARK: - Services

    func getServices() async throws -> [BrewServiceInfo] {
        let result = try await brew("services", "list", "--json")

        guard result.isSuccess else {
            throw BrewError.commandFailed(result.stderr)
        }

        guard let data = result.stdout.data(using: .utf8) else {
            throw BrewError.invalidOutput
        }

        let decoder = JSONDecoder()
        return try decoder.decode([BrewServiceInfo].self, from: data)
    }

    func controlService(name: String, action: ServiceAction) async throws {
        let result = try await brew("services", action.rawValue, name)

        guard result.isSuccess else {
            throw BrewError.commandFailed(result.stderr)
        }
    }

    // MARK: - Update

    func updateBrewData() async throws {
        let result = try await brew("update")
        guard result.isSuccess else {
            throw BrewError.commandFailed(result.stderr)
        }
    }

    // MARK: - Dependencies

    func getDependencyTree(packageName: String) async throws -> DependencyTree {
        let result = try await brew("deps", "--tree", packageName)

        guard result.isSuccess else {
            throw BrewError.commandFailed(result.stderr)
        }

        let lines = result.stdout.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard !lines.isEmpty else {
            return DependencyTree(packageName: packageName, dependencies: [])
        }

        return parseDependencyTree(lines: lines, rootPackage: packageName)
    }

    func getDependents(packageName: String) async throws -> [String] {
        let result = try await brew("uses", "--installed", packageName)

        guard result.isSuccess else {
            // If the command fails, it might mean no dependents exist
            if result.stderr.contains("No formulae") || result.stdout.isEmpty {
                return []
            }
            throw BrewError.commandFailed(result.stderr)
        }

        return result.stdout.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func parseDependencyTree(lines: [String], rootPackage: String) -> DependencyTree {
        guard let firstLine = lines.first else {
            return DependencyTree(packageName: rootPackage, dependencies: [])
        }

        // First line should be the root package
        var currentIndex = 1
        let dependencies = parseChildren(lines: lines, startIndex: &currentIndex, currentIndent: 0)

        return DependencyTree(packageName: rootPackage, dependencies: dependencies)
    }

    private func parseChildren(lines: [String], startIndex: inout Int, currentIndent: Int) -> [DependencyNode] {
        var nodes: [DependencyNode] = []

        while startIndex < lines.count {
            let line = lines[startIndex]
            let indent = getIndentLevel(line)

            // If this line has less or equal indent to our current level, we're done with this level
            if indent <= currentIndent {
                break
            }

            // If this line is a direct child (one indent level deeper)
            if indent == currentIndent + 1 {
                let name = line.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "├──", with: "")
                    .replacingOccurrences(of: "└──", with: "")
                    .replacingOccurrences(of: "│", with: "")
                    .trimmingCharacters(in: .whitespaces)

                startIndex += 1

                // Check if this node has children
                let children: [DependencyNode]
                if startIndex < lines.count && getIndentLevel(lines[startIndex]) > indent {
                    children = parseChildren(lines: lines, startIndex: &startIndex, currentIndent: indent)
                } else {
                    children = []
                }

                nodes.append(DependencyNode(name: name, children: children))
            } else {
                // Skip lines that are not at the expected level
                startIndex += 1
            }
        }

        return nodes
    }

    private func getIndentLevel(_ line: String) -> Int {
        var count = 0
        for char in line {
            if char == " " {
                count += 1
            } else if char == "│" || char == "├" || char == "└" {
                continue
            } else {
                break
            }
        }
        // Each indentation level is typically 2-4 spaces
        return count / 2
    }

    // MARK: - Brewfile

    func exportBrewfile() async throws -> String {
        let result = try await brew("bundle", "dump", "--describe", "--file=-")

        guard result.isSuccess else {
            throw BrewError.commandFailed(result.stderr)
        }

        return result.stdout
    }

    func importBrewfile(content: String) async -> AsyncStream<String> {
        return AsyncStream { continuation in
            Task {
                do {
                    // Create a temporary file for the Brewfile content
                    let tempDir = FileManager.default.temporaryDirectory
                    let brewfilePath = tempDir.appendingPathComponent("Brewfile.\(UUID().uuidString)")

                    try content.write(to: brewfilePath, atomically: true, encoding: .utf8)

                    // Import from the temp file
                    let stream = await importBrewfileFromPath(path: brewfilePath.path)
                    for await line in stream {
                        continuation.yield(line)
                    }

                    // Clean up temp file
                    try? FileManager.default.removeItem(at: brewfilePath)

                    continuation.finish()
                } catch {
                    continuation.yield("Error: \(error.localizedDescription)")
                    continuation.finish()
                }
            }
        }
    }

    func importBrewfileFromPath(path: String) async -> AsyncStream<String> {
        return await brewStream("bundle", "install", "--file=\(path)")
    }

    // MARK: - Pin / Unpin

    func getPinnedPackages() async throws -> [String] {
        let result = try await brew("list", "--pinned")

        guard result.isSuccess else {
            // If command fails, it might mean no packages are pinned
            if result.stderr.contains("No pinned") || result.stdout.isEmpty {
                return []
            }
            throw BrewError.commandFailed(result.stderr)
        }

        return result.stdout.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    func pinPackage(name: String) async throws {
        let result = try await brew("pin", name)

        guard result.isSuccess else {
            throw BrewError.commandFailed(result.stderr)
        }
    }

    func unpinPackage(name: String) async throws {
        let result = try await brew("unpin", name)

        guard result.isSuccess else {
            throw BrewError.commandFailed(result.stderr)
        }
    }

    // MARK: - Package Analysis

    /// Gets leaf packages (packages not required by other packages)
    /// These are typically packages the user intentionally installed
    func getLeafPackages() async throws -> Set<String> {
        let result = try await brew("leaves")

        guard result.isSuccess else {
            return []
        }

        let leaves = result.stdout.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return Set(leaves)
    }

    // MARK: - Taps

    func getTaps() async throws -> [TapInfo] {
        let result = try await brew("tap-info", "--json", "--installed")

        guard result.isSuccess else {
            throw BrewError.commandFailed(result.stderr)
        }

        guard let data = result.stdout.data(using: .utf8) else {
            throw BrewError.invalidOutput
        }

        let decoder = JSONDecoder()
        return try decoder.decode([TapInfo].self, from: data)
    }

    func addTap(name: String) async throws {
        let result = try await brew("tap", name)

        guard result.isSuccess else {
            throw BrewError.commandFailed(result.stderr)
        }
    }

    func removeTap(name: String) async throws {
        let result = try await brew("untap", name)

        guard result.isSuccess else {
            throw BrewError.commandFailed(result.stderr)
        }
    }

    func getTapInfo(name: String) async throws -> TapInfo {
        let result = try await brew("tap-info", name, "--json")

        guard result.isSuccess else {
            throw BrewError.commandFailed(result.stderr)
        }

        guard let data = result.stdout.data(using: .utf8) else {
            throw BrewError.invalidOutput
        }

        let decoder = JSONDecoder()
        let taps = try decoder.decode([TapInfo].self, from: data)

        guard let tapInfo = taps.first else {
            throw BrewError.packageNotFound(name)
        }

        return tapInfo
    }

    // MARK: - Helpers

    private func extractPackageName(from line: String) -> String? {
        let components = line.components(separatedBy: "/")
        if let last = components.last {
            return last.components(separatedBy: " ").first
        }
        return nil
    }

    private func extractBytes(from line: String) -> Int64? {
        let pattern = #"(\d+(?:\.\d+)?)\s*(KB|MB|GB|B)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        guard let numberRange = Range(match.range(at: 1), in: line),
              let unitRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        let numberString = String(line[numberRange])
        let unit = String(line[unitRange]).uppercased()

        guard let number = Double(numberString) else { return nil }

        let multiplier: Double
        switch unit {
        case "KB": multiplier = 1024
        case "MB": multiplier = 1024 * 1024
        case "GB": multiplier = 1024 * 1024 * 1024
        default: multiplier = 1
        }

        return Int64(number * multiplier)
    }

    // MARK: - Quarantine Management

    func getQuarantinedApps() async throws -> [QuarantinedApp] {
        var quarantinedApps: [QuarantinedApp] = []
        let fileManager = FileManager.default

        // Get list of installed casks to match app paths with cask names
        let installedCasks = try await getInstalledCasks()
        let caskMap = Dictionary(uniqueKeysWithValues: installedCasks.map { ($0.displayName.lowercased(), $0.token) })

        // Scan common application directories
        let appDirectories = [
            "/Applications",
            "\(fileManager.homeDirectoryForCurrentUser.path)/Applications"
        ]

        for directory in appDirectories {
            guard fileManager.fileExists(atPath: directory) else { continue }

            do {
                let contents = try fileManager.contentsOfDirectory(atPath: directory)

                for item in contents where item.hasSuffix(".app") {
                    let appPath = "\(directory)/\(item)"

                    // Check if app has quarantine attribute
                    let result = try await shell.execute("xattr -p com.apple.quarantine \"\(appPath)\"")

                    if result.isSuccess && !result.stdout.isEmpty {
                        // Extract quarantine date if available
                        let quarantineDate = extractQuarantineDate(from: result.stdout)

                        // Try to match with a cask
                        let appName = item.replacingOccurrences(of: ".app", with: "")
                        let caskName = caskMap[appName.lowercased()]

                        quarantinedApps.append(QuarantinedApp(
                            name: appName,
                            path: appPath,
                            caskName: caskName,
                            quarantineDate: quarantineDate
                        ))
                    }
                }
            } catch {
                // Continue if directory cannot be read
                continue
            }
        }

        return quarantinedApps
    }

    func removeQuarantine(appPath: String) async throws {
        let result = try await shell.execute("xattr -dr com.apple.quarantine \"\(appPath)\"")

        guard result.isSuccess else {
            throw BrewError.commandFailed("Failed to remove quarantine: \(result.stderr)")
        }
    }

    func getCaskInstallPath(caskName: String) async throws -> String? {
        // Get cask info to find the app name
        let result = try await brew("info", "--cask", caskName)

        guard result.isSuccess else {
            return nil
        }

        // Parse the output to find the app path
        // Typical format: "==> Artifacts\nAppName.app (App)"
        let lines = result.stdout.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            if line.contains("==> Artifacts") && index + 1 < lines.count {
                let nextLine = lines[index + 1]
                if nextLine.contains(".app") {
                    // Extract app name
                    let appName = nextLine.components(separatedBy: " ").first?.trimmingCharacters(in: .whitespaces) ?? ""
                    if !appName.isEmpty {
                        // Check common locations
                        let locations = [
                            "/Applications/\(appName)",
                            "\(FileManager.default.homeDirectoryForCurrentUser.path)/Applications/\(appName)"
                        ]

                        for location in locations {
                            if FileManager.default.fileExists(atPath: location) {
                                return location
                            }
                        }
                    }
                }
            }
        }

        return nil
    }

    private func extractQuarantineDate(from xattrOutput: String) -> Date? {
        // Quarantine attribute format: 0083;XXXXXXXX;Browser;UUID
        // Where XXXXXXXX is hex timestamp
        let components = xattrOutput.components(separatedBy: ";")
        guard components.count >= 2 else { return nil }

        let hexTimestamp = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let intTimestamp = Int(hexTimestamp, radix: 16) else { return nil }
        let timestamp = Double(intTimestamp)

        // Convert from Mac absolute time (seconds since 2001-01-01) to Unix time
        let macEpoch = Date(timeIntervalSinceReferenceDate: 0)
        return Date(timeInterval: timestamp, since: macEpoch)
    }

    // MARK: - MAS (Mac App Store) Operations

    /// Checks if mas CLI is installed
    func isMASInstalled() async -> Bool {
        do {
            let result = try await shell.execute("which mas")
            return result.isSuccess && !result.stdout.isEmpty
        } catch {
            return false
        }
    }

    /// Gets list of installed Mac App Store apps
    func getInstalledMASApps() async throws -> [MASApp] {
        guard await isMASInstalled() else {
            return []
        }

        let result = try await shell.execute("mas list")

        guard result.isSuccess else {
            throw BrewError.commandFailed(result.stderr)
        }

        // Parse output: "123456789 App Name (1.2.3)"
        var apps: [MASApp] = []
        let lines = result.stdout.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Parse format: "ID  Name (Version)"
            if let match = trimmed.firstMatch(of: /^(\d+)\s+(.+?)\s+\((.+?)\)$/) {
                let id = Int(match.1) ?? 0
                let name = String(match.2)
                let version = String(match.3)
                apps.append(MASApp(id: id, name: name, version: version))
            }
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Gets list of outdated Mac App Store apps
    func getOutdatedMASApps() async throws -> [OutdatedMASApp] {
        guard await isMASInstalled() else {
            return []
        }

        let result = try await shell.execute("mas outdated")

        guard result.isSuccess else {
            // mas outdated returns non-zero if no updates, which is fine
            if result.stdout.isEmpty {
                return []
            }
            throw BrewError.commandFailed(result.stderr)
        }

        // Parse output: "123456789 App Name (1.2.3 -> 1.2.4)"
        var apps: [OutdatedMASApp] = []
        let lines = result.stdout.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Parse format: "ID  Name (OldVersion -> NewVersion)"
            if let match = trimmed.firstMatch(of: /^(\d+)\s+(.+?)\s+\((.+?)\s+->\s+(.+?)\)$/) {
                let id = Int(match.1) ?? 0
                let name = String(match.2)
                let installedVersion = String(match.3)
                let availableVersion = String(match.4)
                apps.append(OutdatedMASApp(
                    id: id,
                    name: name,
                    installedVersion: installedVersion,
                    availableVersion: availableVersion
                ))
            }
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Searches Mac App Store for apps
    func searchMAS(query: String) async throws -> [MASSearchResult] {
        guard await isMASInstalled() else {
            return []
        }

        let result = try await shell.execute("mas search \"\(query)\"")

        guard result.isSuccess else {
            throw BrewError.commandFailed(result.stderr)
        }

        // Parse output: "123456789 App Name (1.2.3)"
        var results: [MASSearchResult] = []
        let lines = result.stdout.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Parse format: "ID  Name (Version)"
            if let match = trimmed.firstMatch(of: /^(\d+)\s+(.+?)\s+\((.+?)\)$/) {
                let id = Int(match.1) ?? 0
                let name = String(match.2)
                let version = String(match.3)
                results.append(MASSearchResult(id: id, name: name, version: version, price: nil))
            }
        }

        return results
    }

    /// Installs a Mac App Store app by ID
    func installMASApp(id: Int) async -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                continuation.yield("Installing app from Mac App Store...")

                do {
                    let result = try await shell.execute("mas install \(id)")

                    if result.isSuccess {
                        continuation.yield(result.stdout)
                        continuation.yield("Installation complete!")
                    } else {
                        continuation.yield("Error: \(result.stderr)")
                    }
                } catch {
                    continuation.yield("Error: \(error.localizedDescription)")
                }

                continuation.finish()
            }
        }
    }

    /// Upgrades all outdated Mac App Store apps
    func upgradeMASApps() async -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                continuation.yield("Upgrading Mac App Store apps...")

                do {
                    let result = try await shell.execute("mas upgrade")

                    if result.isSuccess {
                        let output = result.stdout.isEmpty ? "All apps are up to date." : result.stdout
                        continuation.yield(output)
                    } else {
                        continuation.yield("Error: \(result.stderr)")
                    }
                } catch {
                    continuation.yield("Error: \(error.localizedDescription)")
                }

                continuation.finish()
            }
        }
    }

    /// Uninstalls a Mac App Store app (requires admin privileges)
    func uninstallMASApp(id: Int) async -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                continuation.yield("Uninstalling App Store app (ID: \(id))...")

                do {
                    // First, get the app path using dry-run
                    let dryRunResult = try await shell.execute("mas uninstall --dry-run \(id)")

                    // Parse the app path from output like "==> Dry run...\n\n/Applications/AppName.app"
                    let lines = dryRunResult.stdout.components(separatedBy: "\n")
                    guard let appPath = lines.first(where: { $0.hasSuffix(".app") })?.trimmingCharacters(in: .whitespaces),
                          !appPath.isEmpty else {
                        continuation.yield("Error: Could not find app path for ID \(id)")
                        continuation.finish()
                        return
                    }

                    continuation.yield("Found app at: \(appPath)")
                    continuation.yield("Requesting administrator privileges...")

                    // Use rm -rf with admin privileges (mas uninstall has issues with AppleScript sudo)
                    let escapedPath = appPath.replacingOccurrences(of: "\"", with: "\\\"")
                    let script = "do shell script \"rm -rf \\\"\(escapedPath)\\\"\" with administrator privileges"
                    let result = try await shell.execute("osascript -e '\(script)'")

                    if result.isSuccess {
                        continuation.yield("Successfully uninstalled app.")
                    } else {
                        let error = result.stderr.isEmpty ? result.stdout : result.stderr
                        if error.contains("cancelled") || error.contains("canceled") || error.contains("User canceled") {
                            continuation.yield("Uninstall cancelled by user.")
                        } else {
                            continuation.yield("Error: \(error)")
                        }
                    }
                } catch {
                    continuation.yield("Error: \(error.localizedDescription)")
                }

                continuation.finish()
            }
        }
    }

    // MARK: - Package Info

    /// Gets the description for a package
    func getPackageDescription(name: String, isCask: Bool) async throws -> String {
        let result: ShellResult
        if isCask {
            result = try await brew("info", "--cask", name, "--json=v2")
        } else {
            result = try await brew("info", name, "--json=v2")
        }

        guard result.isSuccess, let data = result.stdout.data(using: .utf8) else {
            return ""
        }

        if isCask {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let casks = json["casks"] as? [[String: Any]],
               let cask = casks.first,
               let desc = cask["desc"] as? String {
                return desc
            }
        } else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let formulae = json["formulae"] as? [[String: Any]],
               let formula = formulae.first,
               let desc = formula["desc"] as? String {
                return desc
            }
        }

        return ""
    }

    // MARK: - Discover (Analytics)

    /// Fetches popular packages from Homebrew analytics
    func getPopularPackages() async throws -> [PopularPackage] {
        async let formulaeTask = fetchAnalytics(from: "https://formulae.brew.sh/api/analytics/install-on-request/30d.json", isCask: false)
        async let casksTask = fetchAnalytics(from: "https://formulae.brew.sh/api/analytics/cask-install/30d.json", isCask: true)

        let formulae = (try? await formulaeTask) ?? []
        let casks = (try? await casksTask) ?? []

        // Combine and sort by install count
        return (formulae + casks).sorted { $0.installCount > $1.installCount }
    }

    /// Fetches analytics from Homebrew API
    private func fetchAnalytics(from urlString: String, isCask: Bool) async throws -> [PopularPackage] {
        guard let url = URL(string: urlString) else {
            return []
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(AnalyticsResponse.self, from: data)

        // Take top 100 packages
        return response.items.prefix(100).map { item in
            PopularPackage(
                name: item.packageName,
                installCount: item.installCount,
                rank: item.number,
                isCask: isCask,
                category: PackageCategory.category(for: item.packageName)
            )
        }
    }

    /// Gets popular packages grouped by category
    func getPopularPackagesByCategory() async throws -> [PackageCategory: [PopularPackage]] {
        let packages = try await getPopularPackages()

        var grouped: [PackageCategory: [PopularPackage]] = [:]

        for package in packages {
            grouped[package.category, default: []].append(package)
        }

        // Sort each category by install count and limit to top items
        for (category, items) in grouped {
            grouped[category] = Array(items.sorted { $0.installCount > $1.installCount }.prefix(15))
        }

        return grouped
    }
}

// MARK: - Error Types

enum BrewError: LocalizedError {
    case brewNotInstalled
    case commandFailed(String)
    case packageNotFound(String)
    case invalidOutput
    case serviceControlFailed(String)

    var errorDescription: String? {
        switch self {
        case .brewNotInstalled:
            return "Homebrew is not installed. Visit https://brew.sh to install it."
        case .commandFailed(let message):
            return "Homebrew command failed: \(message)"
        case .packageNotFound(let name):
            return "Package '\(name)' not found"
        case .invalidOutput:
            return "Received invalid output from Homebrew"
        case .serviceControlFailed(let message):
            return "Failed to control service: \(message)"
        }
    }
}

// MARK: - Response Types for JSON Parsing

struct OutdatedResponse: Codable {
    let formulae: [OutdatedFormula]
    let casks: [OutdatedCask]
}

struct OutdatedFormula: Codable {
    let name: String
    let installedVersions: [String]
    let currentVersion: String
    let pinned: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case installedVersions = "installed_versions"
        case currentVersion = "current_version"
        case pinned
    }
}

struct OutdatedCask: Codable {
    let name: String
    let installedVersions: [String]
    let currentVersion: String

    enum CodingKeys: String, CodingKey {
        case name
        case installedVersions = "installed_versions"
        case currentVersion = "current_version"
    }
}

// MARK: - Dependency Tree Types

/// Represents a dependency tree for a package
struct DependencyTree {
    let packageName: String
    let dependencies: [DependencyNode]
}

/// Represents a node in the dependency tree
struct DependencyNode: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let children: [DependencyNode]

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DependencyNode, rhs: DependencyNode) -> Bool {
        lhs.id == rhs.id
    }
}
