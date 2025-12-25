import Foundation

/// Represents an application with macOS quarantine attribute
struct QuarantinedApp: Identifiable, Hashable {
    let name: String
    let path: String
    let caskName: String?
    let quarantineDate: Date?

    var id: String { path }

    /// Returns the app name from the path if name is empty
    var displayName: String {
        if !name.isEmpty {
            return name
        }
        // Extract from path: /Applications/MyApp.app -> MyApp
        let url = URL(fileURLWithPath: path)
        return url.deletingPathExtension().lastPathComponent
    }
}
