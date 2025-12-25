import Foundation

/// Represents a Homebrew formula (command-line package)
struct Formula: Identifiable, Hashable, Codable {
    let name: String
    let fullName: String
    let version: String
    let description: String?
    let homepage: String?
    let installedAsDependency: Bool
    let dependencies: [String]
    let installedOn: Date?

    var id: String { name }
}

/// Response structure for `brew info --json=v2`
struct BrewInfoResponse: Codable {
    let formulae: [FormulaJSON]
    let casks: [CaskJSON]
}

/// JSON structure for formula from brew info
struct FormulaJSON: Codable {
    let name: String
    let fullName: String
    let desc: String?
    let homepage: String?
    let versions: FormulaVersions
    let dependencies: [String]
    let installed: [InstalledInfo]

    enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case desc
        case homepage
        case versions
        case dependencies
        case installed
    }

    func toFormula() -> Formula {
        let installedInfo = installed.first
        return Formula(
            name: name,
            fullName: fullName,
            version: installedInfo?.version ?? versions.stable ?? "unknown",
            description: desc,
            homepage: homepage,
            installedAsDependency: installedInfo?.installedAsDependency ?? false,
            dependencies: dependencies,
            installedOn: installedInfo?.time.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        )
    }
}

struct FormulaVersions: Codable {
    let stable: String?
    let head: String?
}

struct InstalledInfo: Codable {
    let version: String
    let installedAsDependency: Bool
    let installedOnRequest: Bool
    let time: Int?

    enum CodingKeys: String, CodingKey {
        case version
        case installedAsDependency = "installed_as_dependency"
        case installedOnRequest = "installed_on_request"
        case time
    }
}

/// JSON structure for cask from brew info
struct CaskJSON: Codable {
    let token: String
    let fullToken: String?
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
