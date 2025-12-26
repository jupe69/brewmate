import Foundation
import SwiftUI

/// Represents the currently selected section in the sidebar
enum SidebarSection: String, CaseIterable, Identifiable {
    case discover = "Discover"
    case search = "Search"
    case installed = "Installed"
    case formulae = "Formulae"
    case casks = "Casks"
    case updates = "Updates"
    case appStore = "App Store"
    case favorites = "Favorites"
    case pinned = "Pinned"
    case taps = "Taps"
    case services = "Services"
    case brewfile = "Brewfile"
    case diagnostics = "Diagnostics"
    case cleanup = "Cleanup"
    case quarantine = "Quarantine"
    case history = "History"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .discover: return "sparkles"
        case .search: return "magnifyingglass"
        case .formulae: return "terminal"
        case .casks: return "app.badge"
        case .installed: return "checkmark.circle"
        case .updates: return "arrow.up.circle"
        case .appStore: return "bag"
        case .favorites: return "heart.fill"
        case .pinned: return "pin.fill"
        case .taps: return "plus.rectangle.on.folder"
        case .services: return "gearshape.2"
        case .brewfile: return "doc.text"
        case .diagnostics: return "stethoscope"
        case .cleanup: return "trash"
        case .quarantine: return "shield"
        case .history: return "clock.fill"
        }
    }

    var description: String {
        switch self {
        case .discover: return "Popular packages by category"
        case .search: return "Find and install packages"
        case .formulae: return "Command-line packages"
        case .casks: return "GUI applications"
        case .installed: return "All installed packages"
        case .updates: return "Outdated packages"
        case .appStore: return "Mac App Store apps"
        case .favorites: return "Your favorite packages"
        case .pinned: return "Pinned packages"
        case .taps: return "Homebrew repositories"
        case .services: return "Background services"
        case .brewfile: return "Manage Brewfile"
        case .diagnostics: return "System diagnostics and analytics"
        case .cleanup: return "Free up disk space"
        case .quarantine: return "Quarantined packages"
        case .history: return "Installation history"
        }
    }
}

/// Represents a package that can be either a formula or cask
enum Package: Identifiable, Hashable {
    case formula(Formula)
    case cask(Cask)

    var id: String {
        switch self {
        case .formula(let f): return "formula-\(f.id)"
        case .cask(let c): return "cask-\(c.id)"
        }
    }

    var name: String {
        switch self {
        case .formula(let f): return f.name
        case .cask(let c): return c.displayName
        }
    }

    var packageName: String {
        switch self {
        case .formula(let f): return f.name
        case .cask(let c): return c.token
        }
    }

    var version: String {
        switch self {
        case .formula(let f): return f.version
        case .cask(let c): return c.version
        }
    }

    var description: String? {
        switch self {
        case .formula(let f): return f.description
        case .cask(let c): return c.description
        }
    }

    var homepage: String? {
        switch self {
        case .formula(let f): return f.homepage
        case .cask(let c): return c.homepage
        }
    }

    var isCask: Bool {
        if case .cask = self { return true }
        return false
    }

    var isFormula: Bool {
        if case .formula = self { return true }
        return false
    }
}

/// Global application state using Swift 5.9's @Observable macro
@Observable
final class AppState {
    // MARK: - Brew Status
    var brewPath: String?
    var brewVersion: String?
    var isBrewInstalled: Bool { brewPath != nil }

    // MARK: - Loading States
    var isLoading: Bool = false
    var isRefreshing: Bool = false
    var currentOperation: String?

    // MARK: - Data
    var installedFormulae: [Formula] = []
    var installedCasks: [Cask] = []
    var outdatedPackages: [OutdatedPackage] = []
    var services: [BrewServiceInfo] = []
    var taps: [TapInfo] = []
    var pinnedPackages: Set<String> = []
    var leafPackages: Set<String> = []  // Packages not required by others (intentionally installed)

    // MARK: - Mac App Store
    var isMASInstalled: Bool = false
    var masApps: [MASApp] = []
    var outdatedMASApps: [OutdatedMASApp] = []

    // MARK: - User Data
    var userDataManager: UserDataManager = UserDataManager()

    // MARK: - UI State
    var selectedSection: SidebarSection = .installed
    var selectedPackage: Package?
    var searchText: String = ""

    // MARK: - Bulk Operations
    var isSelectionMode: Bool = false
    var selectedPackages: Set<Package> = []

    // MARK: - Error Handling
    var error: AppError?
    var showError: Bool = false

    // MARK: - Operation State
    var operationOutput: [String] = []
    var isOperationInProgress: Bool = false

    // MARK: - Computed Properties

    var allInstalledPackages: [Package] {
        let formulae = installedFormulae.map { Package.formula($0) }
        let casks = installedCasks.map { Package.cask($0) }
        return (formulae + casks).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var filteredPackages: [Package] {
        let packages: [Package]

        switch selectedSection {
        case .search:
            packages = []
        case .formulae:
            packages = installedFormulae.map { Package.formula($0) }
        case .casks:
            packages = installedCasks.map { Package.cask($0) }
        case .installed:
            packages = allInstalledPackages
        case .updates:
            // Return packages that are outdated
            let outdatedNames = Set(outdatedPackages.map { $0.name })
            packages = allInstalledPackages.filter { outdatedNames.contains($0.packageName) }
        case .favorites:
            // Return only favorited packages
            packages = allInstalledPackages.filter { userDataManager.isFavorite($0.packageName) }
        case .pinned:
            // Return only pinned packages
            packages = allInstalledPackages.filter { pinnedPackages.contains($0.packageName) }
        case .services, .taps, .cleanup, .diagnostics, .brewfile, .quarantine, .history, .appStore, .discover:
            packages = []
        }

        if searchText.isEmpty {
            return packages
        }

        return packages.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var outdatedCount: Int {
        outdatedPackages.count
    }

    var outdatedMASCount: Int {
        outdatedMASApps.count
    }

    var favoritesCount: Int {
        userDataManager.favorites.count
    }

    // MARK: - Methods

    func setError(_ error: AppError) {
        self.error = error
        self.showError = true
    }

    func clearError() {
        self.error = nil
        self.showError = false
    }

    func clearOperationOutput() {
        operationOutput.removeAll()
    }

    func appendOperationOutput(_ line: String) {
        operationOutput.append(line)
    }

    func toggleSelectionMode() {
        isSelectionMode.toggle()
        if !isSelectionMode {
            selectedPackages.removeAll()
        }
    }

    func clearSelection() {
        selectedPackages.removeAll()
    }

    func togglePackageSelection(_ package: Package) {
        if selectedPackages.contains(package) {
            selectedPackages.remove(package)
        } else {
            selectedPackages.insert(package)
        }
    }
}

/// Application error types
enum AppError: LocalizedError, Identifiable {
    case brewNotInstalled
    case commandFailed(String)
    case networkError(String)
    case packageNotFound(String)
    case permissionDenied(String)
    case timeout(String)
    case unknown(String)

    var id: String {
        switch self {
        case .brewNotInstalled: return "brew_not_installed"
        case .commandFailed(let msg): return "command_failed_\(msg.prefix(50))"
        case .networkError(let msg): return "network_error_\(msg.prefix(50))"
        case .packageNotFound(let pkg): return "package_not_found_\(pkg)"
        case .permissionDenied(let msg): return "permission_denied_\(msg.prefix(50))"
        case .timeout(let cmd): return "timeout_\(cmd.prefix(50))"
        case .unknown(let msg): return "unknown_\(msg.prefix(50))"
        }
    }

    var errorDescription: String? {
        switch self {
        case .brewNotInstalled:
            return "Homebrew is not installed"
        case .commandFailed(let message):
            return message
        case .networkError(let message):
            return "Network error: \(message)"
        case .packageNotFound(let packageName):
            return "Package '\(packageName)' not found"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .timeout(let command):
            return "Command timed out: \(command)"
        case .unknown(let message):
            return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .brewNotInstalled:
            return "Visit https://brew.sh to install Homebrew"
        case .commandFailed:
            return "Try running 'brew doctor' in Terminal to diagnose issues"
        case .networkError:
            return "Check your internet connection and try again"
        case .packageNotFound:
            return "Check the package name or search for alternatives"
        case .permissionDenied:
            return "Check file permissions or run 'brew doctor' for diagnostics"
        case .timeout:
            return "The command took too long. Try again or check system resources"
        case .unknown:
            return "Please try again or restart the app"
        }
    }

    var icon: String {
        switch self {
        case .brewNotInstalled: return "shippingbox"
        case .commandFailed: return "exclamationmark.triangle"
        case .networkError: return "wifi.slash"
        case .packageNotFound: return "magnifyingglass"
        case .permissionDenied: return "lock.shield"
        case .timeout: return "clock.badge.exclamationmark"
        case .unknown: return "questionmark.circle"
        }
    }
}

/// Environment key for BrewService dependency injection
struct BrewServiceKey: EnvironmentKey {
    static let defaultValue: BrewService = BrewService()
}

extension EnvironmentValues {
    var brewService: BrewService {
        get { self[BrewServiceKey.self] }
        set { self[BrewServiceKey.self] = newValue }
    }
}

