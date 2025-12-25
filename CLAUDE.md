# CLAUDE.md - Project Guide for Claude Code

## Project Overview
Taphouse is a native macOS GUI application for Homebrew package management. Built with SwiftUI for macOS 14.0+ (Sonoma), it provides a clean, native interface for managing formulae, casks, services, taps, and more.

## Tech Stack
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI (no AppKit except where necessary)
- **Architecture**: MVVM with @Observable
- **Minimum Deployment**: macOS 14.0 (Sonoma)
- **Build Tool**: XcodeGen for project generation

## Current Feature Status

### Implemented Features
| Feature | Status | Location |
|---------|--------|----------|
| Package browsing (formulae/casks) | ✅ Complete | PackageListView |
| Search & install packages | ✅ Complete | SearchView |
| Uninstall packages | ✅ Complete | PackageDetailView |
| Update detection & upgrade | ✅ Complete | PackageListView |
| Bulk operations (multi-select) | ✅ Complete | PackageListView |
| Favorites system | ✅ Complete | UserDataManager |
| Package notes | ✅ Complete | PackageDetailView |
| Pin/unpin packages | ✅ Complete | PackageDetailView |
| Services management | ✅ Complete | PackageRowView |
| Taps management | ✅ Complete | TapsView |
| Brewfile import/export | ✅ Complete | BrewfileView |
| Diagnostics (brew doctor) | ✅ Complete | DiagnosticsView |
| Disk usage analysis | ✅ Complete | DiagnosticsView |
| Cache cleanup | ✅ Complete | DiagnosticsView |
| Quarantine management | ✅ Complete | QuarantineView |
| Installation history | ✅ Complete | HistoryView |
| Menu bar icon | ✅ Complete | MenuBarManager |
| Background update checks | ✅ Complete | UpdateScheduler |
| Notifications | ✅ Complete | NotificationManager |
| Dependency tree view | ✅ Complete | DependencyTreeView |
| Mac App Store integration | ✅ Complete | MASView (requires `mas` CLI) |

### Future Enhancements (Not Yet Implemented)
- Package comparison between machines
- Package backup/restore profiles
- Custom tap creation wizard
- Formula/cask analytics dashboard
- Dependency conflict resolution
- Automated testing integration

### TODO: Re-add Keychain for Trial Storage
Currently trial start date is stored in UserDefaults, which can be bypassed by deleting app preferences.
Once the app is properly code-signed with a Developer ID certificate, re-add Keychain storage to prevent
trial bypass on reinstall. The `KeychainManager.swift` was removed because unsigned apps prompt for
Keychain access on every launch, which is a poor user experience.

To re-implement:
1. Create `Core/KeychainManager.swift` with `storeTrialStartDate()` and `getTrialStartDate()` methods
2. Update `LicenseManager.startTrialIfNeeded()` to check Keychain first, then UserDefaults
3. Update `LicenseManager.checkTrialStatus()` similarly
4. Store trial date in both Keychain (persistent) and UserDefaults (fallback)

## Project Structure
```
Taphouse/
├── TaphouseApp.swift              # App entry point, menus, settings
├── Info.plist                      # App configuration
├── Taphouse.entitlements          # Sandbox disabled, hardened runtime
├── Assets.xcassets/               # App icon and colors
├── Core/
│   ├── ShellExecutor.swift        # Async shell command execution
│   ├── BrewPathResolver.swift     # Detects Homebrew installation path
│   ├── BrewService.swift          # Homebrew CLI wrapper (actor)
│   ├── BrewService+Diagnostics.swift # Diagnostics extension
│   ├── MenuBarManager.swift       # Menu bar icon and menu
│   ├── UpdateScheduler.swift      # Background update checks
│   ├── NotificationManager.swift  # Push notifications
│   └── UserDataManager.swift      # Favorites, notes, history persistence
├── Models/
│   ├── Formula.swift              # Formula model + JSON decoding
│   ├── Cask.swift                 # Cask model
│   ├── ServiceInfo.swift          # Services, OutdatedPackage, etc.
│   ├── TapInfo.swift              # Tap repository info
│   ├── QuarantinedApp.swift       # Quarantine status model
│   └── DiagnosticsModels.swift    # Disk usage, cleanup results
├── State/
│   └── AppState.swift             # @Observable global state, 15 sidebar sections
├── Views/
│   ├── ContentView.swift          # Main 3-column NavigationSplitView
│   ├── Sidebar/
│   │   └── SidebarView.swift      # Sidebar with 15 sections
│   ├── Search/
│   │   └── SearchView.swift       # Remote package search + install
│   ├── Packages/
│   │   ├── PackageListView.swift  # Package list with bulk operations
│   │   ├── PackageRowView.swift   # Row components for lists
│   │   ├── PackageDetailView.swift # Package details + actions + notes
│   │   └── DependencyTreeView.swift # Dependency visualization
│   ├── Taps/
│   │   └── TapsView.swift         # Tap management
│   ├── Brewfile/
│   │   └── BrewfileView.swift     # Brewfile import/export
│   ├── Diagnostics/
│   │   └── DiagnosticsView.swift  # Doctor, disk usage, analytics
│   ├── History/
│   │   └── HistoryView.swift      # Installation history
│   ├── Quarantine/
│   │   └── QuarantineView.swift   # Quarantine attribute management
│   ├── AppStore/
│   │   └── MASView.swift          # Mac App Store integration (mas CLI)
│   └── Components/
│       ├── SearchBar.swift        # Reusable search bar
│       └── LoadingView.swift      # Loading, error, empty states
├── Utilities/
│   └── Extensions.swift           # String, View, Date extensions
└── Scripts/
    └── generate-icon.swift        # App icon generator
```

## Key Files to Know

### Core/BrewService.swift
The main interface to Homebrew CLI. Uses an actor for thread safety. Key methods:
- `getInstalledFormulae()` / `getInstalledCasks()` - Lists installed packages
- `search(query:)` - Searches brew catalog
- `install(packageName:isCask:)` - Returns AsyncStream<String> for live output
- `uninstall(packageName:isCask:)` - Removes packages
- `upgrade(packageName:)` - Upgrades packages (nil = upgrade all)
- `getOutdated()` - Lists packages with available updates
- `getServices()` / `controlService(name:action:)` - Manage brew services
- `getTaps()` / `addTap()` / `removeTap()` - Manage taps
- `getPinnedPackages()` / `pinPackage()` / `unpinPackage()` - Pin management
- `getQuarantinedApps()` / `removeQuarantine()` - Quarantine management
- `exportBrewfile()` / `importBrewfile()` - Brewfile operations
- `runDoctor()` - Streaming brew doctor output
- `getDiskUsage()` / `clearCache()` - Disk management

### Core/UserDataManager.swift
Persistent storage for user data:
- Favorites (Set<String>) - stored in ~/Library/Application Support/Taphouse/
- Notes (Dictionary<String, String>) - per-package notes
- History ([HistoryEntry]) - install/uninstall/upgrade log (max 500 entries)

### State/AppState.swift
Global observable state with 15 sidebar sections:
1. Search, 2. Installed, 3. Formulae, 4. Casks, 5. Updates, 6. App Store
7. Favorites, 8. Pinned, 9. Taps, 10. Services, 11. Brewfile
12. Diagnostics, 13. Cleanup, 14. Quarantine, 15. History

## Build Commands
```bash
# Generate Xcode project (required after adding new files)
xcodegen generate

# Build from command line
xcodebuild -project Taphouse.xcodeproj -scheme Taphouse -configuration Debug build

# Clean and rebuild
xcodebuild -project Taphouse.xcodeproj -scheme Taphouse clean build

# Regenerate app icon
cd Scripts && swift generate-icon.swift
```

## Important Patterns

### Async Shell Execution
Shell commands run on `DispatchQueue.global()` with `readabilityHandler` for continuous pipe reading:
```swift
stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
    let data = handle.availableData
    // Process data...
}
process.waitUntilExit()  // Runs on background queue
```

### Environment Injection
BrewService is injected via SwiftUI environment:
```swift
@Environment(\.brewService) private var brewService
```

### Progress Sheet
Operations set `appState.currentOperation` to show the progress sheet:
```swift
appState.currentOperation = "Installing package..."
appState.clearOperationOutput()
let stream = await brewService.install(...)
for await line in stream {
    appState.appendOperationOutput(line)
}
appState.isOperationInProgress = false
```

## Configuration
- **App Sandbox**: DISABLED (required to execute brew commands)
- **Hardened Runtime**: ENABLED (required for notarization)
- **Bundle ID**: com.multimodalsolutions.taphouse

## Common Tasks

### Adding a New Sidebar Section
1. Add case to `SidebarSection` enum in `AppState.swift`
2. Add to switch statements in `AppState.filteredPackages` and `PackageListView`
3. Update `SidebarView` to include the new section
4. Create new view file in appropriate Views/ subdirectory

### Adding a New Brew Command
1. Add method to `BrewServiceProtocol` and `BrewService`
2. Use `brew(...)` for simple commands or `brewStream(...)` for streaming output
3. Parse JSON output using Codable structs in Models/

## Testing Homebrew Commands
```bash
# Check installed formulae JSON structure
brew info --installed --json=v2 | head -100

# Check casks JSON structure
brew info --installed --cask --json=v2 | head -100

# Check outdated JSON structure
brew outdated --json=v2

# Check services JSON structure
brew services list --json

# Check taps JSON structure
brew tap-info --json --installed | head -100

# Check pinned packages
brew list --pinned
```
