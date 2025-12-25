import Foundation

/// Represents a Homebrew service
struct BrewServiceInfo: Identifiable, Codable, Hashable {
    let name: String
    let status: ServiceStatus
    let user: String?
    let file: String?
    let exitCode: Int?

    var id: String { name }

    enum ServiceStatus: String, Codable, Hashable {
        case running = "started"
        case stopped = "stopped"
        case error = "error"
        case unknown = "unknown"
        case scheduled = "scheduled"
        case none = "none"

        var displayName: String {
            switch self {
            case .running: return "Running"
            case .stopped: return "Stopped"
            case .error: return "Error"
            case .unknown: return "Unknown"
            case .scheduled: return "Scheduled"
            case .none: return "Not Running"
            }
        }

        var isActive: Bool {
            self == .running || self == .scheduled
        }
    }

    enum CodingKeys: String, CodingKey {
        case name
        case status
        case user
        case file
        case exitCode = "exit_code"
    }

    init(name: String, status: ServiceStatus, user: String?, file: String?, exitCode: Int? = nil) {
        self.name = name
        self.status = status
        self.user = user
        self.file = file
        self.exitCode = exitCode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)

        // Status can be a string that maps to our enum
        if let statusString = try container.decodeIfPresent(String.self, forKey: .status) {
            status = ServiceStatus(rawValue: statusString.lowercased()) ?? .unknown
        } else {
            status = .unknown
        }

        user = try container.decodeIfPresent(String.self, forKey: .user)
        file = try container.decodeIfPresent(String.self, forKey: .file)
        exitCode = try container.decodeIfPresent(Int.self, forKey: .exitCode)
    }
}

/// Actions that can be performed on a service
enum ServiceAction: String, CaseIterable {
    case start = "start"
    case stop = "stop"
    case restart = "restart"

    var displayName: String {
        switch self {
        case .start: return "Start"
        case .stop: return "Stop"
        case .restart: return "Restart"
        }
    }

    var systemImage: String {
        switch self {
        case .start: return "play.fill"
        case .stop: return "stop.fill"
        case .restart: return "arrow.clockwise"
        }
    }
}

/// Represents an outdated package that can be upgraded
struct OutdatedPackage: Identifiable, Hashable {
    let name: String
    let installedVersion: String
    let currentVersion: String
    let isCask: Bool
    let pinned: Bool

    var id: String { name }

    init(name: String, installedVersion: String, currentVersion: String, isCask: Bool, pinned: Bool = false) {
        self.name = name
        self.installedVersion = installedVersion
        self.currentVersion = currentVersion
        self.isCask = isCask
        self.pinned = pinned
    }
}

/// Result of a cleanup operation
struct CleanupResult {
    let bytesFreed: Int64
    let formulaeRemoved: [String]
    let casksRemoved: [String]
    let downloadsCleaned: Int

    var formattedBytesFreed: String {
        ByteCountFormatter.string(fromByteCount: bytesFreed, countStyle: .file)
    }

    var isEmpty: Bool {
        bytesFreed == 0 && formulaeRemoved.isEmpty && casksRemoved.isEmpty && downloadsCleaned == 0
    }
}

/// A diagnostic issue found by `brew doctor`
struct DiagnosticIssue: Identifiable, Hashable {
    let id = UUID()
    let category: String
    let message: String
    let severity: Severity

    enum Severity: String {
        case warning
        case error

        var systemImage: String {
            switch self {
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }
    }
}

/// Search results containing both formulae and casks
struct SearchResults {
    let formulae: [String]
    let casks: [String]

    var isEmpty: Bool {
        formulae.isEmpty && casks.isEmpty
    }

    var totalCount: Int {
        formulae.count + casks.count
    }
}
