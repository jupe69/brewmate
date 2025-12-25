import Foundation

/// Manages caching of package information for faster loading
actor PackageCache {
    static let shared = PackageCache()

    private let cacheDirectory: URL
    private let formulaeCacheFile = "formulae_cache.json"
    private let casksCacheFile = "casks_cache.json"
    private let outdatedCacheFile = "outdated_cache.json"

    /// Cache validity duration in seconds (default: 5 minutes)
    private let cacheValidityDuration: TimeInterval = 300

    private struct CachedData<T: Codable>: Codable {
        let data: T
        let timestamp: Date
    }

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDirectory = appSupport.appendingPathComponent("BrewMate/Cache", isDirectory: true)

        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Formulae Cache

    func cacheFormulae(_ formulae: [Formula]) {
        let cached = CachedData(data: formulae, timestamp: Date())
        save(cached, to: formulaeCacheFile)
    }

    func getCachedFormulae() -> [Formula]? {
        guard let cached: CachedData<[Formula]> = load(from: formulaeCacheFile) else {
            return nil
        }

        guard isValid(timestamp: cached.timestamp) else {
            return nil
        }

        return cached.data
    }

    // MARK: - Casks Cache

    func cacheCasks(_ casks: [Cask]) {
        let cached = CachedData(data: casks, timestamp: Date())
        save(cached, to: casksCacheFile)
    }

    func getCachedCasks() -> [Cask]? {
        guard let cached: CachedData<[Cask]> = load(from: casksCacheFile) else {
            return nil
        }

        guard isValid(timestamp: cached.timestamp) else {
            return nil
        }

        return cached.data
    }

    // MARK: - Outdated Cache

    func cacheOutdated(_ outdated: [OutdatedPackage]) {
        let cached = CachedData(data: outdated, timestamp: Date())
        save(cached, to: outdatedCacheFile)
    }

    func getCachedOutdated() -> [OutdatedPackage]? {
        guard let cached: CachedData<[OutdatedPackage]> = load(from: outdatedCacheFile) else {
            return nil
        }

        guard isValid(timestamp: cached.timestamp) else {
            return nil
        }

        return cached.data
    }

    // MARK: - Cache Management

    func invalidateAll() {
        try? FileManager.default.removeItem(at: cacheDirectory.appendingPathComponent(formulaeCacheFile))
        try? FileManager.default.removeItem(at: cacheDirectory.appendingPathComponent(casksCacheFile))
        try? FileManager.default.removeItem(at: cacheDirectory.appendingPathComponent(outdatedCacheFile))
    }

    func invalidateOutdated() {
        try? FileManager.default.removeItem(at: cacheDirectory.appendingPathComponent(outdatedCacheFile))
    }

    /// Returns cache age for formulae in seconds, or nil if no cache
    func getFormulaeAge() -> TimeInterval? {
        guard let cached: CachedData<[Formula]> = load(from: formulaeCacheFile) else {
            return nil
        }
        return Date().timeIntervalSince(cached.timestamp)
    }

    // MARK: - Private Helpers

    private func isValid(timestamp: Date) -> Bool {
        return Date().timeIntervalSince(timestamp) < cacheValidityDuration
    }

    private func save<T: Codable>(_ data: T, to filename: String) {
        let url = cacheDirectory.appendingPathComponent(filename)
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: url, options: .atomic)
        } catch {
            print("Failed to save cache: \(error)")
        }
    }

    private func load<T: Codable>(from filename: String) -> T? {
        let url = cacheDirectory.appendingPathComponent(filename)
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }
}
