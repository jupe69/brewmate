# Taphouse

A beautiful, native macOS GUI for [Homebrew](https://brew.sh) package management.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange?logo=swift)
![License](https://img.shields.io/badge/License-MIT-green)

## Pricing

Taphouse offers a **free version** with essential functionality, plus a **Pro upgrade** for power users.

| | Free | Pro |
|---|:---:|:---:|
| Browse & search packages | ✓ | ✓ |
| Install, uninstall, upgrade | ✓ | ✓ |
| Services management | ✓ | ✓ |
| Diagnostics (brew doctor) | ✓ | ✓ |
| **Bulk operations** | | ✓ |
| **Favorites & notes** | | ✓ |
| **Installation history** | | ✓ |
| **Taps management** | | ✓ |
| **Quarantine management** | | ✓ |
| **Pin packages** | | ✓ |
| **Menu bar integration** | | ✓ |
| **Background update checks** | | ✓ |
| **Auto-upgrade packages** | | ✓ |
| **Brewfile import/export** | | ✓ |
| **Cleanup tools** | | ✓ |
| **App Store integration** | | ✓ |
| **Price** | Free | $4.99 (one-time) |

**14-day free trial** of all Pro features included.

[Purchase Pro](https://multimodal.lemonsqueezy.com/checkout/buy/7483a6ae-cbc7-404e-ae41-6ef2e7108baf)

---

## Features

### Free Features

#### Package Management
- **Browse Installed Packages** - View all installed formulae and casks in an organized list
- **Search & Install** - Search Homebrew's entire catalog and install packages with one click
- **Uninstall Packages** - Remove packages with confirmation dialogs
- **View Package Details** - See descriptions, versions, dependencies, and homepage links
- **Dependency Detection** - Packages installed as dependencies are marked with a "dep" badge, distinguishing them from packages you explicitly installed

#### Updates & Upgrades
- **Outdated Package Detection** - Instantly see which packages have updates available
- **One-Click Updates** - Update individual packages or upgrade everything at once
- **Live Progress Output** - Watch installation and upgrade progress in real-time

#### Services Management
- **Status Overview** - See running, stopped, and error counts at a glance
- **View All Services** - See all Homebrew-managed background services grouped by status
- **Service Status** - Color-coded status indicators (running, stopped, scheduled, error)
- **Start/Stop/Restart** - Control services directly from the app
- **Auto-Refresh** - Monitor services with configurable refresh intervals (10s to 5min)
- **Context Menus** - Right-click for quick actions and "Show in Finder"

#### Diagnostics
- **Brew Doctor** - Run system health checks with streaming output
- **Disk Usage** - View space used by cache, Cellar, and Caskroom
- **Analytics Control** - Enable/disable Homebrew analytics

### Pro Features

#### Bulk Operations
- **Multi-Select** - Select multiple packages at once
- **Bulk Install/Uninstall/Upgrade** - Manage many packages in a single operation

#### User Data
- **Favorites** - Mark packages as favorites for quick access
- **Package Notes** - Add personal notes to any package
- **Installation History** - Track all install/uninstall/upgrade actions

#### Taps (Repositories)
- **View Installed Taps** - See all configured Homebrew repositories
- **Add/Remove Taps** - Manage third-party taps with ease
- **Tap Details** - View formula and cask counts per tap

#### Quarantine Management
- **Scan Applications** - Find apps with macOS quarantine attributes
- **Remove Quarantine** - Clear quarantine flags from trusted applications
- **Match to Casks** - Automatically match apps to their Homebrew casks

#### Package Pinning
- **Pin Packages** - Prevent specific packages from being auto-upgraded

#### Brewfile Support
- **Export Brewfile** - Generate a Brewfile from your installed packages
- **Import Brewfile** - Install packages from an existing Brewfile
- **Descriptions Included** - Exported Brewfiles include package descriptions as comments

#### Cleanup Tools
- **Disk Usage Overview** - Visual cards showing cache, Cellar, and Caskroom sizes
- **Cleanup Preview** - Scan and preview what will be removed before cleaning
- **Standard Cleanup** - Remove old package versions and outdated downloads
- **Deep Cleanup** - Clear all cached downloads for maximum space recovery

#### Mac App Store Integration
- **Browse Installed Apps** - View all Mac App Store apps installed on your system
- **Check for Updates** - See which App Store apps have updates available
- **Search App Store** - Find and install apps directly from the Mac App Store
- **Upgrade All** - Update all outdated App Store apps with one click
- **Uninstall Apps** - Remove App Store apps directly from Taphouse (requires admin password)
- **Requires `mas` CLI** - Install via `brew install mas`

#### Menu Bar Integration
- **Status Icon** - Optional menu bar icon with update badge
- **Quick Actions** - Check for updates or upgrade all from the menu bar
- **Outdated List** - See outdated packages without opening the main window
- **Services Control** - Start, stop, and restart Homebrew services directly from the menu bar
- **Menu Bar Only Mode** - Run Taphouse as a menu bar app only, hiding the dock icon completely

#### Background Features
- **Automatic Update Checks** - Configurable hourly/daily/weekly checks
- **Auto-Upgrade** - Optionally upgrade packages automatically
- **Battery Aware** - Skip auto-upgrades when battery is low
- **Notifications** - Get notified when updates are available

### Native macOS Experience
- **SwiftUI Interface** - Built entirely with SwiftUI for a native look and feel
- **3-Column Layout** - Familiar navigation split view design
- **Dark Mode Support** - Seamlessly adapts to your system appearance
- **Keyboard Shortcuts** - Cmd+R to refresh, Cmd+Shift+U for updates, and more
- **Skeleton Loading** - Smooth loading placeholders while fetching data
- **Contextual Empty States** - Helpful messages when lists are empty
- **Enhanced Error Handling** - Clear error messages with recovery suggestions

### First-Run Experience
- **Guided Onboarding** - Step-by-step wizard for new users
- **Homebrew Installation Guide** - Clear instructions with copy-to-clipboard command
- **Quick Launch Terminal** - One-click button to open Terminal for installation
- **Installation Check** - Verify Homebrew installation before proceeding

### Performance
- **Package Caching** - Cache package data locally for faster startup
- **Background Refresh** - Update cache silently after displaying cached data
- **Automatic Cache Invalidation** - Smart cache expiry (5 minutes)
- **Lazy Loading** - Large package lists load incrementally for smooth scrolling
- **Auto-Pagination** - Automatically loads more items as you scroll

### Network & Proxy Support
- **System Proxy Detection** - Automatically uses macOS system proxy settings
- **Corporate Environment Ready** - Works behind HTTP, HTTPS, and SOCKS proxies
- **Proxy Exception Support** - Respects system proxy bypass rules
- **Zero Configuration** - No manual proxy setup required

### Widget Support (Requires Code Signing)
- **Desktop Widget** - macOS widget showing outdated package count
- **Multiple Sizes** - Small, medium, and large widget variants
- **Live Updates** - Widget refreshes when package status changes
- **Quick Access** - Click widget to open Taphouse

## Requirements

- **macOS 14.0** (Sonoma) or later
- **Homebrew** installed on your system
- **Xcode 15.0+** (for building from source)

## Installation

### Download Release
Download the latest release from the [Releases](https://github.com/yourusername/taphouse/releases) page.

### Build from Source

1. **Install XcodeGen** (if not already installed):
   ```bash
   brew install xcodegen
   ```

2. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/taphouse.git
   cd taphouse
   ```

3. **Generate the Xcode project**:
   ```bash
   xcodegen generate
   ```

4. **Open in Xcode**:
   ```bash
   open Taphouse.xcodeproj
   ```

5. **Build and Run** (Cmd+R)

## Usage

### Sidebar Sections

| Section | Description |
|---------|-------------|
| Search | Find and install new packages |
| Installed | All installed packages |
| Formulae | Command-line tools only |
| Casks | GUI applications only |
| Updates | Packages with available upgrades |
| App Store | Mac App Store apps (requires `mas`) |
| Favorites | Your marked favorite packages |
| Pinned | Packages excluded from auto-upgrade |
| Taps | Homebrew repositories |
| Services | Background services control |
| Brewfile | Import/export package lists |
| Diagnostics | System health and disk usage |
| Cleanup | Free up disk space |
| Quarantine | Manage app quarantine flags |
| History | Installation action log |

### Installing a Package
1. Click **Search** in the sidebar
2. Type the package name and press Enter
3. Select a package from the results
4. Click **Install**

### Updating Packages
1. Click **Updates** in the sidebar
2. Click **Update All** or select individual packages to update

### Managing Services
1. Click **Services** in the sidebar
2. Use the play/stop/restart buttons to control each service

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+R | Refresh package list |
| Cmd+F | Focus search field |
| Cmd+, | Open Preferences |
| Cmd+Shift+U | Check for updates |
| Cmd+Shift+S | Toggle selection mode |
| Escape | Exit selection mode / Clear selection |

## Preferences

Access preferences via **Taphouse > Settings** (Cmd+,):

### General
- Refresh packages when app becomes active
- Confirm before uninstalling packages
- Show dependencies in package details
- Show menu bar icon
- Services auto-refresh with configurable interval

### Updates
- Update check frequency (daily/weekly/monthly)
- Enable automatic upgrades
- Auto-upgrade frequency

### About
- View Homebrew installation path and version
- Quick links to Homebrew documentation

## Architecture

Taphouse is built with a clean MVVM architecture:

```
Taphouse/
├── Core/           # Shell execution, Homebrew service, managers
├── Models/         # Data models with Codable support
├── State/          # Observable app state
├── Views/          # SwiftUI views organized by feature
└── Utilities/      # Extensions and helpers
```

### Key Technologies
- **Swift 5.9** with modern concurrency (async/await, actors)
- **SwiftUI** for the entire user interface
- **@Observable** macro for reactive state management
- **XcodeGen** for project file generation

## Security

- **App Sandbox**: Disabled (required to execute brew commands)
- **Hardened Runtime**: Enabled (required for notarization)
- No network requests except those made by Homebrew itself

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Development

See [CLAUDE.md](CLAUDE.md) for detailed development documentation, including:
- Project structure and key files
- Build commands
- Important implementation patterns
- How to add new features

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Homebrew](https://brew.sh) - The missing package manager for macOS
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) - Xcode project generation

---

Made with care for the Mac community
