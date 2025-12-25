import Foundation

/// Represents an installed Mac App Store application
struct MASApp: Identifiable, Hashable {
    let id: Int
    let name: String
    let version: String

    var appStoreURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(id)")
    }
}

/// Represents an outdated Mac App Store application
struct OutdatedMASApp: Identifiable, Hashable {
    let id: Int
    let name: String
    let installedVersion: String
    let availableVersion: String

    var appStoreURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(id)")
    }
}

/// Represents a Mac App Store search result
struct MASSearchResult: Identifiable, Hashable {
    let id: Int
    let name: String
    let version: String
    let price: String?

    var appStoreURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(id)")
    }

    var isFree: Bool {
        price == nil || price == "0" || price?.lowercased() == "free"
    }
}
