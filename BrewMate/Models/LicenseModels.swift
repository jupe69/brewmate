import Foundation

// MARK: - License Status

/// Represents the current license state
enum LicenseStatus: String, Codable {
    case unknown    // Not yet determined
    case trial      // In trial period
    case active     // Valid paid license
    case expired    // Trial or license expired
    case invalid    // License key is invalid
}

// MARK: - Trial Info

/// Information about the trial period
struct TrialInfo: Codable {
    let startDate: Date
    let expirationDate: Date

    var daysRemaining: Int {
        let remaining = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
        return max(0, remaining)
    }

    var isExpired: Bool {
        Date() >= expirationDate
    }

    var progress: Double {
        let total = Calendar.current.dateComponents([.day], from: startDate, to: expirationDate).day ?? 14
        let elapsed = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return min(1.0, Double(elapsed) / Double(total))
    }
}

// MARK: - License Info (persisted locally)

/// Stored license information
struct LicenseInfo: Codable {
    let licenseKey: String
    let instanceId: String
    let status: String
    let customerEmail: String?
    let activatedAt: Date
    let expiresAt: Date?

    /// Masked license key for display (shows first and last 4 chars)
    var maskedKey: String {
        guard licenseKey.count > 8 else { return licenseKey }
        let prefix = String(licenseKey.prefix(4))
        let suffix = String(licenseKey.suffix(4))
        return "\(prefix)-****-****-\(suffix)"
    }
}

// MARK: - LemonSqueezy API Response Types

/// Response from license activation endpoint
struct ActivationResponse: Codable {
    let activated: Bool
    let error: String?
    let licenseKey: LicenseKeyDetails
    let instance: InstanceDetails?
    let meta: LicenseMeta?

    enum CodingKeys: String, CodingKey {
        case activated, error, instance, meta
        case licenseKey = "license_key"
    }
}

/// Response from license validation endpoint
struct ValidationResponse: Codable {
    let valid: Bool
    let error: String?
    let licenseKey: LicenseKeyDetails
    let instance: InstanceDetails?
    let meta: LicenseMeta?

    enum CodingKeys: String, CodingKey {
        case valid, error, instance, meta
        case licenseKey = "license_key"
    }
}

/// License key details from API
struct LicenseKeyDetails: Codable {
    let id: Int
    let status: String
    let key: String
    let activationLimit: Int?
    let activationUsage: Int
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, status, key
        case activationLimit = "activation_limit"
        case activationUsage = "activation_usage"
        case expiresAt = "expires_at"
    }
}

/// Instance details from API (device/machine binding)
struct InstanceDetails: Codable {
    let id: String
    let name: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case createdAt = "created_at"
    }
}

/// Metadata from API response
struct LicenseMeta: Codable {
    let storeId: Int?
    let orderId: Int?
    let productId: Int?
    let productName: String?
    let customerEmail: String?

    enum CodingKeys: String, CodingKey {
        case storeId = "store_id"
        case orderId = "order_id"
        case productId = "product_id"
        case productName = "product_name"
        case customerEmail = "customer_email"
    }
}

// MARK: - License Errors

/// Errors that can occur during license operations
enum LicenseError: LocalizedError {
    case networkError(String)
    case activationFailed(String)
    case validationFailed(String)
    case deactivationFailed(String)
    case trialExpired
    case noLicense
    case invalidKey

    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .activationFailed(let message):
            return "Activation failed: \(message)"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .deactivationFailed(let message):
            return "Deactivation failed: \(message)"
        case .trialExpired:
            return "Your trial has expired"
        case .noLicense:
            return "No valid license found"
        case .invalidKey:
            return "Invalid license key format"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Please check your internet connection and try again."
        case .activationFailed:
            return "Please verify your license key and try again."
        case .validationFailed:
            return "Your license may have been deactivated. Please contact support."
        case .deactivationFailed:
            return "Please try again or contact support."
        case .trialExpired:
            return "Purchase BrewMate Pro to continue using all features."
        case .noLicense:
            return "Enter a license key or start a free trial."
        case .invalidKey:
            return "Please check your license key format."
        }
    }
}

// MARK: - Pro Features

/// Features that require a Pro license
enum ProFeature: String, CaseIterable, Identifiable {
    case menuBar = "Menu Bar Integration"
    case backgroundUpdates = "Background Updates"
    case brewfile = "Brewfile Import/Export"
    case cleanup = "Cleanup Tools"

    var id: String { rawValue }

    var name: String { rawValue }

    var description: String {
        switch self {
        case .menuBar:
            return "Quick access from your menu bar with update badges and one-click actions."
        case .backgroundUpdates:
            return "Automatic update checks and notifications when new package versions are available."
        case .brewfile:
            return "Export your Homebrew setup and import it on another Mac for easy migration."
        case .cleanup:
            return "Free up disk space by removing old package versions and clearing the cache."
        }
    }

    var systemImage: String {
        switch self {
        case .menuBar: return "menubar.rectangle"
        case .backgroundUpdates: return "bell.badge"
        case .brewfile: return "doc.text"
        case .cleanup: return "trash"
        }
    }
}
