import Foundation

/// Represents a Homebrew cask (GUI application)
struct Cask: Identifiable, Codable, Hashable {
    let token: String
    let name: [String]
    let version: String
    let description: String?
    let homepage: String?

    var id: String { token }

    /// Returns the primary display name for the cask
    var displayName: String {
        name.first ?? token
    }

    enum CodingKeys: String, CodingKey {
        case token
        case name
        case version
        case description = "desc"
        case homepage
    }

    init(token: String, name: [String], version: String, description: String?, homepage: String?) {
        self.token = token
        self.name = name
        self.version = version
        self.description = description
        self.homepage = homepage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        token = try container.decode(String.self, forKey: .token)

        // Name can be a string array or a single string
        if let nameArray = try? container.decode([String].self, forKey: .name) {
            name = nameArray
        } else if let singleName = try? container.decode(String.self, forKey: .name) {
            name = [singleName]
        } else {
            name = []
        }

        version = try container.decode(String.self, forKey: .version)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        homepage = try container.decodeIfPresent(String.self, forKey: .homepage)
    }
}

/// Detailed cask info from `brew info --json=v2`
struct CaskInfo: Codable {
    let token: String
    let fullToken: String
    let name: [String]
    let version: String
    let desc: String?
    let homepage: String?
    let installed: String?

    enum CodingKeys: String, CodingKey {
        case token
        case fullToken = "full_token"
        case name
        case version
        case desc
        case homepage
        case installed
    }

    var isInstalled: Bool {
        installed != nil
    }

    func toCask() -> Cask {
        Cask(
            token: token,
            name: name,
            version: installed ?? version,
            description: desc,
            homepage: homepage
        )
    }
}
