import Foundation

/// Manages data sharing between the main app and the widget
/// Note: Widget support requires App Groups which need a development certificate.
/// When building with proper code signing, enable the widget target in project.yml.
final class WidgetDataManager {
    static let shared = WidgetDataManager()

    private let appGroupIdentifier = "group.com.multimodalsolutions.brewmate"
    private let dataFileName = "widget_data.json"

    private init() {}

    /// Data structure shared with the widget
    struct WidgetData: Codable {
        let outdatedCount: Int
        let outdatedPackages: [String]
        let lastUpdated: Date
    }

    /// Updates the widget data with current outdated packages
    func updateWidgetData(outdatedPackages: [OutdatedPackage]) {
        let data = WidgetData(
            outdatedCount: outdatedPackages.count,
            outdatedPackages: outdatedPackages.map { $0.name },
            lastUpdated: Date()
        )

        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            // App Groups not available (requires development certificate)
            // Widget will use placeholder data
            return
        }

        // Ensure the container directory exists
        do {
            try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        } catch {
            // Silently fail - widget data is optional
            return
        }

        let fileURL = containerURL.appendingPathComponent(dataFileName)

        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: fileURL, options: .atomic)

            // Reload all widget timelines (requires WidgetKit import when widget is enabled)
            // WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // Silently fail - widget data is optional
        }
    }

    /// Clears all widget data (for when no updates are available)
    func clearWidgetData() {
        updateWidgetData(outdatedPackages: [])
    }
}
