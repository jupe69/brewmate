import Foundation

/// Manages user data persistence for favorites, notes, and installation history
@Observable
final class UserDataManager {
    // MARK: - Properties

    private(set) var favorites: Set<String> = []
    private(set) var notes: [String: String] = [:]
    private(set) var history: [HistoryEntry] = []

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - File URLs

    private var appSupportDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let brewMateDir = appSupport.appendingPathComponent("BrewMate", isDirectory: true)

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: brewMateDir.path) {
            try? fileManager.createDirectory(at: brewMateDir, withIntermediateDirectories: true)
        }

        return brewMateDir
    }

    private var favoritesURL: URL {
        appSupportDirectory.appendingPathComponent("favorites.json")
    }

    private var notesURL: URL {
        appSupportDirectory.appendingPathComponent("notes.json")
    }

    private var historyURL: URL {
        appSupportDirectory.appendingPathComponent("history.json")
    }

    // MARK: - Initialization

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601

        loadAll()
    }

    // MARK: - Favorites

    func isFavorite(_ packageName: String) -> Bool {
        favorites.contains(packageName)
    }

    func toggleFavorite(_ packageName: String) {
        if favorites.contains(packageName) {
            favorites.remove(packageName)
        } else {
            favorites.insert(packageName)
        }
        saveFavorites()
    }

    func addFavorite(_ packageName: String) {
        favorites.insert(packageName)
        saveFavorites()
    }

    func removeFavorite(_ packageName: String) {
        favorites.remove(packageName)
        saveFavorites()
    }

    // MARK: - Notes

    func getNote(for packageName: String) -> String? {
        notes[packageName]
    }

    func setNote(_ note: String, for packageName: String) {
        if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notes.removeValue(forKey: packageName)
        } else {
            notes[packageName] = note
        }
        saveNotes()
    }

    func removeNote(for packageName: String) {
        notes.removeValue(forKey: packageName)
        saveNotes()
    }

    func hasNote(for packageName: String) -> Bool {
        notes[packageName] != nil
    }

    // MARK: - History

    func addHistoryEntry(action: HistoryAction, packageName: String, isCask: Bool, success: Bool) {
        let entry = HistoryEntry(
            timestamp: Date(),
            action: action,
            packageName: packageName,
            isCask: isCask,
            success: success
        )
        history.insert(entry, at: 0) // Insert at beginning for chronological order (newest first)

        // Limit history to 500 entries
        if history.count > 500 {
            history = Array(history.prefix(500))
        }

        saveHistory()
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    func getRecentHistory(limit: Int = 50) -> [HistoryEntry] {
        Array(history.prefix(limit))
    }

    // MARK: - Persistence

    private func loadAll() {
        loadFavorites()
        loadNotes()
        loadHistory()
    }

    private func loadFavorites() {
        guard fileManager.fileExists(atPath: favoritesURL.path),
              let data = try? Data(contentsOf: favoritesURL),
              let decoded = try? decoder.decode(Set<String>.self, from: data) else {
            favorites = []
            return
        }
        favorites = decoded
    }

    private func saveFavorites() {
        guard let data = try? encoder.encode(favorites) else { return }
        try? data.write(to: favoritesURL, options: .atomic)
    }

    private func loadNotes() {
        guard fileManager.fileExists(atPath: notesURL.path),
              let data = try? Data(contentsOf: notesURL),
              let decoded = try? decoder.decode([String: String].self, from: data) else {
            notes = [:]
            return
        }
        notes = decoded
    }

    private func saveNotes() {
        guard let data = try? encoder.encode(notes) else { return }
        try? data.write(to: notesURL, options: .atomic)
    }

    private func loadHistory() {
        guard fileManager.fileExists(atPath: historyURL.path),
              let data = try? Data(contentsOf: historyURL),
              let decoded = try? decoder.decode([HistoryEntry].self, from: data) else {
            history = []
            return
        }
        history = decoded
    }

    private func saveHistory() {
        guard let data = try? encoder.encode(history) else { return }
        try? data.write(to: historyURL, options: .atomic)
    }
}

// MARK: - Models

/// Represents a single entry in the installation history
struct HistoryEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    let action: HistoryAction
    let packageName: String
    let isCask: Bool
    let success: Bool

    init(id: UUID = UUID(), timestamp: Date, action: HistoryAction, packageName: String, isCask: Bool, success: Bool) {
        self.id = id
        self.timestamp = timestamp
        self.action = action
        self.packageName = packageName
        self.isCask = isCask
        self.success = success
    }

    var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    var absoluteTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

/// Types of actions that can be logged in history
enum HistoryAction: String, Codable, CaseIterable {
    case install = "install"
    case uninstall = "uninstall"
    case upgrade = "upgrade"

    var displayName: String {
        switch self {
        case .install: return "Installed"
        case .uninstall: return "Uninstalled"
        case .upgrade: return "Upgraded"
        }
    }

    var systemImage: String {
        switch self {
        case .install: return "arrow.down.circle.fill"
        case .uninstall: return "trash.fill"
        case .upgrade: return "arrow.up.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .install: return "green"
        case .uninstall: return "red"
        case .upgrade: return "blue"
        }
    }
}
