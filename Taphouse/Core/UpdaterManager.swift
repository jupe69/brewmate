import Foundation
import Sparkle
import SwiftUI

/// Manages app updates via Sparkle framework
final class UpdaterManager: ObservableObject {
    /// Shared instance
    static let shared = UpdaterManager()

    /// The Sparkle updater controller
    private let updaterController: SPUStandardUpdaterController

    /// Published property to track if updates can be checked
    @Published var canCheckForUpdates = false

    private init() {
        // Initialize Sparkle updater
        // Setting startingUpdater to true will automatically check for updates on launch
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        // Observe the canCheckForUpdates property
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    /// Manually check for updates
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    /// The underlying updater for advanced configuration
    var updater: SPUUpdater {
        updaterController.updater
    }
}

/// SwiftUI view for the "Check for Updates" menu item
struct CheckForUpdatesView: View {
    @ObservedObject private var updaterManager = UpdaterManager.shared

    var body: some View {
        Button("Check for Updates...") {
            updaterManager.checkForUpdates()
        }
        .disabled(!updaterManager.canCheckForUpdates)
    }
}
