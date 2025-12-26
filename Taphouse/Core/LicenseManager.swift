import Foundation

/// Manages license validation, trial tracking, and Pro feature access
@Observable
final class LicenseManager {
    // MARK: - Singleton

    static let shared = LicenseManager()

    // MARK: - License State

    private(set) var licenseStatus: LicenseStatus = .unknown
    private(set) var licenseInfo: LicenseInfo?
    private(set) var trialInfo: TrialInfo?
    private(set) var isValidating: Bool = false
    private(set) var lastValidationDate: Date?
    private(set) var lastError: LicenseError?

    // MARK: - Computed Properties

    /// Returns true if user has Pro access (valid license or active trial)
    var isPro: Bool {
        switch licenseStatus {
        case .active, .trial:
            return true
        case .expired, .invalid, .unknown:
            return false
        }
    }

    /// Returns true if currently in trial period
    var isTrialActive: Bool {
        if case .trial = licenseStatus { return true }
        return false
    }

    /// Returns true if user has a paid license (not trial)
    var hasLicense: Bool {
        licenseInfo != nil && licenseStatus == .active
    }

    /// Days remaining in trial, or nil if not in trial
    var trialDaysRemaining: Int? {
        guard isTrialActive, let trialInfo = trialInfo else { return nil }
        return trialInfo.daysRemaining
    }

    // MARK: - Configuration

    /// LemonSqueezy API base URL
    private let apiBaseURL = "https://api.lemonsqueezy.com/v1/licenses"

    /// Purchase URL for Taphouse Pro
    static let purchaseURL = URL(string: "https://multimodal.lemonsqueezy.com/checkout/buy/3697ac37-9b65-421e-9d29-0c9e5221ebc2")!

    /// Trial duration in days
    private let trialDurationDays = 14

    /// Offline validation grace period in days
    private let offlineGracePeriodDays = 7

    // MARK: - Persistence

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var appSupportDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let taphouseDir = appSupport.appendingPathComponent("Taphouse", isDirectory: true)
        if !fileManager.fileExists(atPath: taphouseDir.path) {
            try? fileManager.createDirectory(at: taphouseDir, withIntermediateDirectories: true)
        }
        return taphouseDir
    }

    private var licenseFileURL: URL {
        appSupportDirectory.appendingPathComponent("license.json")
    }

    // MARK: - UserDefaults Keys

    private enum DefaultsKeys {
        static let trialStartDate = "taphouse.trialStartDate"
        static let lastValidationDate = "taphouse.lastValidationDate"
    }

    // MARK: - Initialization

    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        loadLicenseState()
    }

    // MARK: - Trial Management

    /// Starts a trial if one hasn't been started and no license exists
    func startTrialIfNeeded() {
        // Don't start trial if we have a license
        guard licenseInfo == nil else { return }

        // Check Keychain first (most persistent, survives reinstall)
        if let trialStart = KeychainManager.getTrialStartDate() {
            let trialEnd = Calendar.current.date(byAdding: .day, value: trialDurationDays, to: trialStart)!
            trialInfo = TrialInfo(startDate: trialStart, expirationDate: trialEnd)

            // Sync to UserDefaults if missing
            if UserDefaults.standard.object(forKey: DefaultsKeys.trialStartDate) == nil {
                UserDefaults.standard.set(trialStart, forKey: DefaultsKeys.trialStartDate)
            }

            if Date() < trialEnd {
                licenseStatus = .trial
            } else {
                licenseStatus = .expired
            }
            return
        }

        // Fall back to UserDefaults (for users upgrading from older version)
        if let trialStart = UserDefaults.standard.object(forKey: DefaultsKeys.trialStartDate) as? Date {
            let trialEnd = Calendar.current.date(byAdding: .day, value: trialDurationDays, to: trialStart)!
            trialInfo = TrialInfo(startDate: trialStart, expirationDate: trialEnd)

            // Migrate to Keychain for persistence
            KeychainManager.storeTrialStartDate(trialStart)

            if Date() < trialEnd {
                licenseStatus = .trial
            } else {
                licenseStatus = .expired
            }
            return
        }

        // Start new trial - store in both Keychain and UserDefaults
        let trialStart = Date()
        let trialEnd = Calendar.current.date(byAdding: .day, value: trialDurationDays, to: trialStart)!

        KeychainManager.storeTrialStartDate(trialStart)
        UserDefaults.standard.set(trialStart, forKey: DefaultsKeys.trialStartDate)

        trialInfo = TrialInfo(startDate: trialStart, expirationDate: trialEnd)
        licenseStatus = .trial
    }

    /// Checks and updates trial status
    func checkTrialStatus() {
        guard licenseInfo == nil else { return }

        // Check Keychain first, then UserDefaults
        let trialStart = KeychainManager.getTrialStartDate()
            ?? UserDefaults.standard.object(forKey: DefaultsKeys.trialStartDate) as? Date

        if let trialStart = trialStart {
            let trialEnd = Calendar.current.date(byAdding: .day, value: trialDurationDays, to: trialStart)!
            trialInfo = TrialInfo(startDate: trialStart, expirationDate: trialEnd)

            // Ensure Keychain has the value for persistence
            if KeychainManager.getTrialStartDate() == nil {
                KeychainManager.storeTrialStartDate(trialStart)
            }

            if Date() < trialEnd {
                licenseStatus = .trial
            } else {
                licenseStatus = .expired
            }
        } else {
            // No trial started yet
            startTrialIfNeeded()
        }
    }

    // MARK: - License Activation

    /// Activates a license key with LemonSqueezy
    func activateLicense(key: String) async throws {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw LicenseError.invalidKey
        }

        isValidating = true
        lastError = nil
        defer { isValidating = false }

        let instanceName = Host.current().localizedName ?? "Taphouse-Mac"

        guard let url = URL(string: "\(apiBaseURL)/activate") else {
            throw LicenseError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let encodedKey = trimmedKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmedKey
        let encodedName = instanceName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? instanceName
        let body = "license_key=\(encodedKey)&instance_name=\(encodedName)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LicenseError.networkError("Invalid response")
        }

        if httpResponse.statusCode != 200 {
            // Try to parse error from response
            if let errorResponse = try? decoder.decode(ActivationResponse.self, from: data) {
                throw LicenseError.activationFailed(errorResponse.error ?? "Unknown error")
            }
            throw LicenseError.activationFailed("HTTP \(httpResponse.statusCode)")
        }

        let activationResponse = try decoder.decode(ActivationResponse.self, from: data)

        if activationResponse.activated {
            // Store license info
            licenseInfo = LicenseInfo(
                licenseKey: trimmedKey,
                instanceId: activationResponse.instance?.id ?? "",
                status: activationResponse.licenseKey.status,
                customerEmail: activationResponse.meta?.customerEmail,
                activatedAt: Date(),
                expiresAt: activationResponse.licenseKey.expiresAt
            )
            licenseStatus = .active
            lastValidationDate = Date()
            saveLicenseState()
        } else {
            let errorMessage = activationResponse.error ?? "Activation was not successful"
            lastError = .activationFailed(errorMessage)
            throw LicenseError.activationFailed(errorMessage)
        }
    }

    // MARK: - License Validation

    /// Validates the current license with LemonSqueezy
    func validateLicense() async throws {
        guard let license = licenseInfo else {
            checkTrialStatus()
            return
        }

        isValidating = true
        lastError = nil
        defer { isValidating = false }

        guard let url = URL(string: "\(apiBaseURL)/validate") else {
            throw LicenseError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var body = "license_key=\(license.licenseKey)"
        if !license.instanceId.isEmpty {
            body += "&instance_id=\(license.instanceId)"
        }
        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        let validationResponse = try decoder.decode(ValidationResponse.self, from: data)

        if validationResponse.valid {
            licenseStatus = .active
            lastValidationDate = Date()
            saveLicenseState()
        } else {
            licenseStatus = .invalid
            let errorMessage = validationResponse.error ?? "License is no longer valid"
            lastError = .validationFailed(errorMessage)
        }
    }

    /// Validates license on app startup, handling offline scenarios
    func validateOnStartup() async {
        guard licenseInfo != nil else {
            checkTrialStatus()
            return
        }

        // Check if we can use cached validation
        if validateOffline() {
            // Still try to validate online in background
            Task {
                try? await validateLicense()
            }
            return
        }

        // Must validate online
        do {
            try await validateLicense()
        } catch {
            // Network error - check grace period
            if let lastValidation = lastValidationDate {
                let daysSince = Calendar.current.dateComponents([.day], from: lastValidation, to: Date()).day ?? Int.max
                if daysSince > offlineGracePeriodDays {
                    licenseStatus = .invalid
                    lastError = .networkError("Unable to validate license. Please check your internet connection.")
                }
                // Otherwise within grace period - keep current status
            } else {
                // Never validated - mark as invalid
                licenseStatus = .invalid
                lastError = .noLicense
            }
        }
    }

    // MARK: - Offline Validation

    /// Returns true if cached validation is still valid for offline use
    func validateOffline() -> Bool {
        guard let lastValidation = lastValidationDate else { return false }

        let daysSinceValidation = Calendar.current.dateComponents(
            [.day],
            from: lastValidation,
            to: Date()
        ).day ?? Int.max

        // Trust cached status if validated within grace period
        return daysSinceValidation <= offlineGracePeriodDays && licenseStatus == .active
    }

    // MARK: - License Deactivation

    /// Deactivates the license from this device
    func deactivateLicense() async throws {
        guard let license = licenseInfo else { return }

        isValidating = true
        defer { isValidating = false }

        guard let url = URL(string: "\(apiBaseURL)/deactivate") else {
            throw LicenseError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "license_key=\(license.licenseKey)&instance_id=\(license.instanceId)"
        request.httpBody = body.data(using: .utf8)

        _ = try await URLSession.shared.data(for: request)

        // Clear local license regardless of API response
        clearLocalLicense()
    }

    /// Clears the local license without calling the API
    func clearLocalLicense() {
        licenseInfo = nil
        licenseStatus = .unknown
        lastValidationDate = nil
        try? fileManager.removeItem(at: licenseFileURL)

        // Check if trial is still available
        checkTrialStatus()
    }

    // MARK: - Persistence

    private func loadLicenseState() {
        // Load stored license info
        if fileManager.fileExists(atPath: licenseFileURL.path),
           let data = try? Data(contentsOf: licenseFileURL),
           let license = try? decoder.decode(LicenseInfo.self, from: data) {
            licenseInfo = license
            licenseStatus = .active // Will be re-validated on startup
        }

        // Load cached validation date
        if let lastValidation = UserDefaults.standard.object(forKey: DefaultsKeys.lastValidationDate) as? Date {
            lastValidationDate = lastValidation
        }

        // If no license, check trial
        if licenseInfo == nil {
            checkTrialStatus()
        }
    }

    private func saveLicenseState() {
        if let license = licenseInfo,
           let data = try? encoder.encode(license) {
            try? data.write(to: licenseFileURL, options: .atomic)
        }

        if let lastValidation = lastValidationDate {
            UserDefaults.standard.set(lastValidation, forKey: DefaultsKeys.lastValidationDate)
        }
    }
}
