import Foundation

/// Represents a Homebrew tap (third-party repository)
struct TapInfo: Identifiable, Codable, Hashable {
    let name: String
    let user: String
    let repo: String
    let path: String
    let formulaCount: Int
    let caskCount: Int
    let commandCount: Int
    let remote: String?
    let isOfficial: Bool

    var id: String { name }

    /// Display name for the tap
    var displayName: String {
        name
    }

    /// Total count of all items in the tap
    var totalCount: Int {
        formulaCount + caskCount + commandCount
    }

    enum CodingKeys: String, CodingKey {
        case name
        case user
        case repo
        case path
        case formulaCount = "formula_names"
        case caskCount = "cask_tokens"
        case commandCount = "command_files"
        case remote
        case isOfficial = "official"
    }

    init(name: String, user: String, repo: String, path: String, formulaCount: Int, caskCount: Int, commandCount: Int, remote: String?, isOfficial: Bool) {
        self.name = name
        self.user = user
        self.repo = repo
        self.path = path
        self.formulaCount = formulaCount
        self.caskCount = caskCount
        self.commandCount = commandCount
        self.remote = remote
        self.isOfficial = isOfficial
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        user = try container.decode(String.self, forKey: .user)
        repo = try container.decode(String.self, forKey: .repo)
        path = try container.decode(String.self, forKey: .path)
        remote = try container.decodeIfPresent(String.self, forKey: .remote)
        isOfficial = try container.decodeIfPresent(Bool.self, forKey: .isOfficial) ?? false

        // These are arrays in the JSON, we just need the count
        if let formulae = try? container.decode([String].self, forKey: .formulaCount) {
            formulaCount = formulae.count
        } else {
            formulaCount = 0
        }

        if let casks = try? container.decode([String].self, forKey: .caskCount) {
            caskCount = casks.count
        } else {
            caskCount = 0
        }

        if let commands = try? container.decode([String].self, forKey: .commandCount) {
            commandCount = commands.count
        } else {
            commandCount = 0
        }
    }
}

/// Simple tap info for listing (from `brew tap`)
struct SimpleTapInfo: Identifiable, Hashable {
    let name: String

    var id: String { name }

    var displayName: String {
        name
    }
}
