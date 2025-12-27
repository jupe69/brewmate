import Foundation
import AppKit
import SwiftUI

/// Manages app icon fetching from various sources with caching
actor IconManager {
    static let shared = IconManager()

    // MARK: - Rate Limiting

    /// Maximum concurrent API requests
    private let maxConcurrentRequests = 3

    /// Current number of active API requests
    private var activeRequests = 0

    /// Queue of waiting requests
    private var waitingRequests: [CheckedContinuation<Void, Never>] = []

    /// Set of packages we've already tried and failed to get icons for (negative cache)
    private var failedLookups: Set<String> = []

    /// Request timeout in seconds
    private let requestTimeout: TimeInterval = 5.0

    // MARK: - Cache

    private var memoryCache: [String: NSImage] = [:]
    private let fileManager = FileManager.default

    private var cacheDirectory: URL {
        let appSupport = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let iconCache = appSupport.appendingPathComponent("Taphouse/Icons", isDirectory: true)
        if !fileManager.fileExists(atPath: iconCache.path) {
            try? fileManager.createDirectory(at: iconCache, withIntermediateDirectories: true)
        }
        return iconCache
    }

    // MARK: - Rate Limiting Helpers

    private func acquireSlot() async {
        if activeRequests < maxConcurrentRequests {
            activeRequests += 1
            return
        }

        // Wait for a slot
        await withCheckedContinuation { continuation in
            waitingRequests.append(continuation)
        }
        activeRequests += 1
    }

    private func releaseSlot() {
        activeRequests -= 1
        if let next = waitingRequests.first {
            waitingRequests.removeFirst()
            next.resume()
        }
    }

    // MARK: - Public API

    /// Get icon for a package (cask or formula)
    func getIcon(for packageName: String, isCask: Bool) async -> NSImage? {
        // Check memory cache first
        let cacheKey = "\(isCask ? "cask" : "formula")_\(packageName)"
        if let cached = memoryCache[cacheKey] {
            return cached
        }

        // Check disk cache
        if let diskCached = loadFromDiskCache(key: cacheKey) {
            memoryCache[cacheKey] = diskCached
            return diskCached
        }

        // For formulae, return nil (will use fallback icon)
        if !isCask {
            return nil
        }

        // Check if we've already failed to find this icon
        if failedLookups.contains(cacheKey) {
            return nil
        }

        // For casks, try multiple sources
        var icon: NSImage?

        // 1. Try installed app bundle first (fast, no network)
        icon = getInstalledAppIconSync(for: packageName)

        // 2. Try iTunes Search API (with rate limiting)
        if icon == nil {
            await acquireSlot()
            defer { Task { await releaseSlot() } }

            icon = await fetchiTunesIconWithTimeout(for: packageName)
        }

        // Cache the result
        if let icon = icon {
            memoryCache[cacheKey] = icon
            saveToDiskCache(image: icon, key: cacheKey)
        } else {
            // Remember that we failed so we don't try again
            failedLookups.insert(cacheKey)
        }

        return icon
    }

    /// Get icon for a Mac App Store app by ID
    func getMASIcon(appId: String, appName: String) async -> NSImage? {
        let cacheKey = "mas_\(appId)"

        // Check memory cache
        if let cached = memoryCache[cacheKey] {
            return cached
        }

        // Check disk cache
        if let diskCached = loadFromDiskCache(key: cacheKey) {
            memoryCache[cacheKey] = diskCached
            return diskCached
        }

        // Check negative cache
        if failedLookups.contains(cacheKey) {
            return nil
        }

        // Acquire rate limit slot
        await acquireSlot()
        defer { Task { await releaseSlot() } }

        // Fetch from iTunes API with timeout
        if let icon = await fetchiTunesIconByIdWithTimeout(appId: appId) {
            memoryCache[cacheKey] = icon
            saveToDiskCache(image: icon, key: cacheKey)
            return icon
        }

        // Fallback: try installed app (sync, no network)
        if let icon = getInstalledAppIconSync(for: appName) {
            memoryCache[cacheKey] = icon
            saveToDiskCache(image: icon, key: cacheKey)
            return icon
        }

        failedLookups.insert(cacheKey)
        return nil
    }

    /// Preload icons for a list of packages (for better UX)
    func preloadIcons(for packages: [(name: String, isCask: Bool)]) async {
        await withTaskGroup(of: Void.self) { group in
            for package in packages.prefix(10) { // Limit to 10 concurrent
                group.addTask {
                    _ = await self.getIcon(for: package.name, isCask: package.isCask)
                }
            }
        }
    }

    // MARK: - iTunes API

    private func fetchiTunesIconWithTimeout(for appName: String) async -> NSImage? {
        await withTaskGroup(of: NSImage?.self) { group in
            group.addTask {
                await self.fetchiTunesIcon(for: appName)
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(self.requestTimeout * 1_000_000_000))
                return nil
            }

            // Return first result (either the icon or timeout)
            for await result in group {
                group.cancelAll()
                return result
            }
            return nil
        }
    }

    private func fetchiTunesIconByIdWithTimeout(appId: String) async -> NSImage? {
        await withTaskGroup(of: NSImage?.self) { group in
            group.addTask {
                await self.fetchiTunesIconById(appId: appId)
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(self.requestTimeout * 1_000_000_000))
                return nil
            }

            for await result in group {
                group.cancelAll()
                return result
            }
            return nil
        }
    }

    private func fetchiTunesIcon(for appName: String) async -> NSImage? {
        // Clean up the name for search (remove common suffixes)
        let searchName = appName
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")

        guard let encodedName = searchName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encodedName)&entity=macSoftware&limit=3&country=us") else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(iTunesSearchResponse.self, from: data)

            // Find best match
            if let result = findBestMatch(for: appName, in: response.results) {
                return await downloadImage(from: result.artworkUrl512 ?? result.artworkUrl100)
            }
        } catch {
            // Silently fail - icons are optional
        }

        return nil
    }

    private func fetchiTunesIconById(appId: String) async -> NSImage? {
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(appId)&country=us") else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(iTunesSearchResponse.self, from: data)

            if let result = response.results.first {
                return await downloadImage(from: result.artworkUrl512 ?? result.artworkUrl100)
            }
        } catch {
            // Silently fail
        }

        return nil
    }

    private func findBestMatch(for searchName: String, in results: [iTunesResult]) -> iTunesResult? {
        let lowercasedSearch = searchName.lowercased()

        // Exact match first
        if let exact = results.first(where: { $0.trackName.lowercased() == lowercasedSearch }) {
            return exact
        }

        // Starts with match
        if let startsWith = results.first(where: { $0.trackName.lowercased().hasPrefix(lowercasedSearch) }) {
            return startsWith
        }

        // Contains match
        if let contains = results.first(where: { $0.trackName.lowercased().contains(lowercasedSearch) }) {
            return contains
        }

        // Just return first result if any
        return results.first
    }

    private func downloadImage(from urlString: String?) async -> NSImage? {
        guard let urlString = urlString,
              // Get higher resolution by replacing size in URL
              let url = URL(string: urlString.replacingOccurrences(of: "100x100", with: "256x256")) else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return NSImage(data: data)
        } catch {
            return nil
        }
    }

    // MARK: - Local App Icons

    /// Synchronous check for installed app icon (fast, no network, no async directory search)
    private func getInstalledAppIconSync(for packageName: String) -> NSImage? {
        // Common app locations - check these quickly without async
        let possiblePaths = [
            "/Applications/\(packageName).app",
            "/Applications/\(packageName.capitalized).app",
            "/Applications/\(formatAppName(packageName)).app",
            NSHomeDirectory() + "/Applications/\(packageName).app",
            NSHomeDirectory() + "/Applications/\(formatAppName(packageName)).app"
        ]

        for path in possiblePaths {
            if fileManager.fileExists(atPath: path) {
                return NSWorkspace.shared.icon(forFile: path)
            }
        }

        return nil
    }

    private func getInstalledAppIcon(for packageName: String) async -> NSImage? {
        // Common app locations
        let possiblePaths = [
            "/Applications/\(packageName).app",
            "/Applications/\(packageName.capitalized).app",
            "/Applications/\(formatAppName(packageName)).app",
            NSHomeDirectory() + "/Applications/\(packageName).app",
            NSHomeDirectory() + "/Applications/\(formatAppName(packageName)).app"
        ]

        for path in possiblePaths {
            if fileManager.fileExists(atPath: path) {
                return NSWorkspace.shared.icon(forFile: path)
            }
        }

        // Try to find by searching Applications folder
        if let icon = await searchApplicationsFolder(for: packageName) {
            return icon
        }

        return nil
    }

    private func formatAppName(_ name: String) -> String {
        // Convert kebab-case or snake_case to Title Case
        name.split(separator: "-")
            .flatMap { $0.split(separator: "_") }
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    private func searchApplicationsFolder(for packageName: String) async -> NSImage? {
        let applicationsURL = URL(fileURLWithPath: "/Applications")
        let lowercasedName = packageName.lowercased()

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: applicationsURL,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            for appURL in contents where appURL.pathExtension == "app" {
                let appName = appURL.deletingPathExtension().lastPathComponent.lowercased()
                if appName.contains(lowercasedName) || lowercasedName.contains(appName) {
                    return NSWorkspace.shared.icon(forFile: appURL.path)
                }
            }
        } catch {
            // Ignore errors
        }

        return nil
    }

    // MARK: - Disk Cache

    private func loadFromDiskCache(key: String) -> NSImage? {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).png")
        guard let data = try? Data(contentsOf: fileURL),
              let image = NSImage(data: data) else {
            return nil
        }
        return image
    }

    private func saveToDiskCache(image: NSImage, key: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).png")

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return
        }

        try? pngData.write(to: fileURL)
    }

    /// Clear all cached icons
    func clearCache() {
        memoryCache.removeAll()
        try? fileManager.removeItem(at: cacheDirectory)
    }
}

// MARK: - iTunes API Models

private struct iTunesSearchResponse: Codable {
    let resultCount: Int
    let results: [iTunesResult]
}

private struct iTunesResult: Codable {
    let trackName: String
    let artworkUrl100: String?
    let artworkUrl512: String?

    enum CodingKeys: String, CodingKey {
        case trackName
        case artworkUrl100
        case artworkUrl512
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trackName = try container.decode(String.self, forKey: .trackName)
        artworkUrl100 = try container.decodeIfPresent(String.self, forKey: .artworkUrl100)

        // artworkUrl512 might not exist, try to derive from artworkUrl100
        if let url100 = try container.decodeIfPresent(String.self, forKey: .artworkUrl100) {
            artworkUrl512 = url100.replacingOccurrences(of: "100x100", with: "512x512")
        } else {
            artworkUrl512 = nil
        }
    }
}

// MARK: - SwiftUI View Extension

struct AppIconView: View {
    let packageName: String
    let isCask: Bool
    let size: CGFloat

    @State private var icon: NSImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
            } else if isLoading {
                RoundedRectangle(cornerRadius: size * 0.2)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: size, height: size)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.5)
                    )
            } else {
                // Fallback icon
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.2)
                        .fill(isCask ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
                    Image(systemName: isCask ? "app.fill" : "terminal.fill")
                        .font(.system(size: size * 0.5))
                        .foregroundStyle(isCask ? .blue : .green)
                }
                .frame(width: size, height: size)
            }
        }
        .task {
            await loadIcon()
        }
    }

    private func loadIcon() async {
        let loadedIcon = await IconManager.shared.getIcon(for: packageName, isCask: isCask)
        await MainActor.run {
            self.icon = loadedIcon
            self.isLoading = false
        }
    }
}

struct MASAppIconView: View {
    let appId: String
    let appName: String
    let size: CGFloat

    @State private var icon: NSImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
            } else if isLoading {
                RoundedRectangle(cornerRadius: size * 0.2)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: size, height: size)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.5)
                    )
            } else {
                // Fallback icon
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.2)
                        .fill(Color.blue.opacity(0.1))
                    Image(systemName: "app.badge.fill")
                        .font(.system(size: size * 0.5))
                        .foregroundStyle(.blue)
                }
                .frame(width: size, height: size)
            }
        }
        .task {
            await loadIcon()
        }
    }

    private func loadIcon() async {
        let loadedIcon = await IconManager.shared.getMASIcon(appId: appId, appName: appName)
        await MainActor.run {
            self.icon = loadedIcon
            self.isLoading = false
        }
    }
}
