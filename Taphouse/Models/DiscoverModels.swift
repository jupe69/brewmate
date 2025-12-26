import Foundation

/// Category for organizing discovered packages
enum PackageCategory: String, CaseIterable, Identifiable {
    case development = "Development"
    case productivity = "Productivity"
    case utilities = "Utilities"
    case media = "Media & Graphics"
    case communication = "Communication"
    case security = "Security"
    case databases = "Databases"
    case cloud = "Cloud & DevOps"
    case browsers = "Browsers"
    case other = "Other"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .development: return "hammer"
        case .productivity: return "doc.text"
        case .utilities: return "wrench.and.screwdriver"
        case .media: return "photo"
        case .communication: return "message"
        case .security: return "lock.shield"
        case .databases: return "cylinder"
        case .cloud: return "cloud"
        case .browsers: return "globe"
        case .other: return "square.grid.2x2"
        }
    }

    /// Maps known packages to categories
    static func category(for packageName: String) -> PackageCategory {
        let name = packageName.lowercased()

        // Development
        let devPackages = ["git", "gh", "node", "python", "python@3", "go", "rust", "ruby", "java", "openjdk",
                          "vim", "neovim", "emacs", "cmake", "make", "gcc", "llvm", "swift", "kotlin",
                          "maven", "gradle", "npm", "yarn", "pnpm", "composer", "pip", "cargo",
                          "visual-studio-code", "sublime-text", "atom", "intellij-idea", "xcode",
                          "iterm2", "warp", "terminal", "fig", "docker", "podman", "lazygit", "lazydocker",
                          "typescript", "deno", "bun", "zig", "elixir", "erlang", "scala", "clojure",
                          "flutter", "react-native", "cocoapods", "fastlane", "swiftlint", "swiftformat"]

        let prodPackages = ["notion", "obsidian", "evernote", "todoist", "things", "fantastical",
                           "alfred", "raycast", "rectangle", "magnet", "bettertouchtool", "karabiner-elements",
                           "microsoft-word", "microsoft-excel", "microsoft-powerpoint", "libreoffice",
                           "notion-calendar", "cron", "busycal"]

        let utilPackages = ["wget", "curl", "htop", "btop", "tmux", "tree", "jq", "yq", "ripgrep", "fd",
                           "fzf", "bat", "exa", "eza", "lsd", "zoxide", "starship", "fish", "zsh",
                           "the-unarchiver", "keka", "appcleaner", "cleanmymac", "onyx", "stats",
                           "mas", "homebrew-cask", "trash", "coreutils", "findutils", "gnu-sed",
                           "imageoptim", "handbrake", "ffmpeg", "yt-dlp", "youtube-dl"]

        let mediaPackages = ["ffmpeg", "imagemagick", "gimp", "inkscape", "blender", "vlc", "iina",
                            "spotify", "apple-music", "audacity", "obs", "screenflow", "figma",
                            "sketch", "adobe-creative-cloud", "photoshop", "illustrator", "premiere",
                            "davinci-resolve", "final-cut-pro", "logic-pro", "garageband", "mpv",
                            "plex", "jellyfin", "kodi"]

        let commPackages = ["slack", "discord", "zoom", "microsoft-teams", "telegram", "signal",
                           "whatsapp", "messenger", "skype", "webex", "element", "mattermost"]

        let secPackages = ["1password", "bitwarden", "lastpass", "keepassxc", "gpg", "gnupg",
                          "openssl", "openssh", "wireguard", "openvpn", "tunnelblick", "little-snitch",
                          "lulu", "oversight", "blockblock", "knockknock", "malwarebytes", "clamav"]

        let dbPackages = ["postgresql", "mysql", "mariadb", "sqlite", "mongodb", "redis", "memcached",
                         "elasticsearch", "cassandra", "couchdb", "neo4j", "dbeaver", "tableplus",
                         "sequel-pro", "mongodb-compass", "redis-insight", "pgadmin4"]

        let cloudPackages = ["awscli", "azure-cli", "google-cloud-sdk", "terraform", "ansible", "pulumi",
                            "kubectl", "helm", "minikube", "kind", "k9s", "lens", "docker", "docker-compose",
                            "vagrant", "packer", "consul", "vault", "nomad", "argocd", "flux"]

        let browserPackages = ["google-chrome", "firefox", "brave-browser", "microsoft-edge", "arc",
                              "safari", "opera", "vivaldi", "chromium", "tor-browser", "orion"]

        if devPackages.contains(where: { name.contains($0) }) { return .development }
        if prodPackages.contains(where: { name.contains($0) }) { return .productivity }
        if utilPackages.contains(where: { name.contains($0) }) { return .utilities }
        if mediaPackages.contains(where: { name.contains($0) }) { return .media }
        if commPackages.contains(where: { name.contains($0) }) { return .communication }
        if secPackages.contains(where: { name.contains($0) }) { return .security }
        if dbPackages.contains(where: { name.contains($0) }) { return .databases }
        if cloudPackages.contains(where: { name.contains($0) }) { return .cloud }
        if browserPackages.contains(where: { name.contains($0) }) { return .browsers }

        return .other
    }
}

/// A popular package from Homebrew analytics
struct PopularPackage: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let installCount: Int
    let rank: Int
    let isCask: Bool
    let category: PackageCategory

    var formattedCount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: installCount)) ?? "\(installCount)"
    }
}

/// Response from Homebrew analytics API
struct AnalyticsResponse: Codable {
    let category: String
    let totalItems: Int
    let startDate: String
    let endDate: String
    let totalCount: Int
    let items: [AnalyticsItem]

    enum CodingKeys: String, CodingKey {
        case category
        case totalItems = "total_items"
        case startDate = "start_date"
        case endDate = "end_date"
        case totalCount = "total_count"
        case items
    }
}

/// Individual item from analytics response
struct AnalyticsItem: Codable {
    let number: Int
    let formula: String?
    let cask: String?
    let count: String
    let percent: String

    var packageName: String {
        formula ?? cask ?? ""
    }

    var installCount: Int {
        Int(count.replacingOccurrences(of: ",", with: "")) ?? 0
    }
}
