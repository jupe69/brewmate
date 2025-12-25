import SwiftUI

/// License management tab in Settings
struct LicenseSettingsView: View {
    @Environment(\.openURL) private var openURL
    @State private var showActivation = false
    @State private var showDeactivateConfirm = false
    @State private var isDeactivating = false
    @State private var deactivateError: String?

    private var licenseManager: LicenseManager { LicenseManager.shared }

    var body: some View {
        Form {
            // Status Section
            Section {
                HStack {
                    statusBadge
                    Spacer()
                    if licenseManager.isValidating {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if let email = licenseManager.licenseInfo?.customerEmail {
                    LabeledContent("Registered to") {
                        Text(email)
                            .foregroundStyle(.secondary)
                    }
                }

                if let maskedKey = licenseManager.licenseInfo?.maskedKey {
                    LabeledContent("License key") {
                        Text(maskedKey)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                if let lastValidation = licenseManager.lastValidationDate {
                    LabeledContent("Last validated") {
                        Text(lastValidation, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("License Status")
            }

            // Trial info
            if licenseManager.isTrialActive, let trialInfo = licenseManager.trialInfo {
                Section {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.orange)
                        Text("\(trialInfo.daysRemaining) day\(trialInfo.daysRemaining == 1 ? "" : "s") remaining in your trial")
                    }

                    ProgressView(value: trialInfo.progress)
                        .tint(.orange)

                    Text("Your trial started on \(trialInfo.startDate.formatted(date: .abbreviated, time: .omitted)) and expires on \(trialInfo.expirationDate.formatted(date: .abbreviated, time: .omitted)).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Trial Period")
                }
            }

            // Pro features
            Section {
                ForEach(ProFeature.allCases) { feature in
                    HStack {
                        Image(systemName: feature.systemImage)
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.name)
                                .font(.subheadline)
                            Text(feature.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        if licenseManager.isPro {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Pro Features")
            }

            // Actions
            Section {
                if licenseManager.licenseInfo == nil {
                    Button("Activate License Key") {
                        showActivation = true
                    }

                    Button {
                        openURL(LicenseManager.purchaseURL)
                    } label: {
                        HStack {
                            Text("Purchase BrewMate Pro")
                            Spacer()
                            Text("$9.99")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Button("Validate License") {
                        Task {
                            try? await licenseManager.validateLicense()
                        }
                    }
                    .disabled(licenseManager.isValidating)

                    Button("Deactivate License", role: .destructive) {
                        showDeactivateConfirm = true
                    }
                    .disabled(isDeactivating)
                }
            } header: {
                Text("Actions")
            } footer: {
                if licenseManager.licenseInfo != nil {
                    Text("Deactivating will remove the license from this device. You can reactivate it later on this or another device.")
                }
            }

            // Error display
            if let error = deactivateError {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .foregroundStyle(.red)
                    }
                    .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showActivation) {
            ActivationView()
        }
        .confirmationDialog("Deactivate License?", isPresented: $showDeactivateConfirm, titleVisibility: .visible) {
            Button("Deactivate", role: .destructive) {
                Task {
                    isDeactivating = true
                    deactivateError = nil
                    do {
                        try await licenseManager.deactivateLicense()
                    } catch {
                        deactivateError = error.localizedDescription
                    }
                    isDeactivating = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the license from this device. You can reactivate it later.")
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch licenseManager.licenseStatus {
        case .active:
            Label("Pro", systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .font(.headline)
        case .trial:
            Label("Trial", systemImage: "clock.fill")
                .foregroundStyle(.orange)
                .font(.headline)
        case .expired:
            Label("Expired", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.headline)
        case .invalid:
            Label("Invalid", systemImage: "xmark.seal.fill")
                .foregroundStyle(.red)
                .font(.headline)
        case .unknown:
            Label("Free", systemImage: "person.fill")
                .foregroundStyle(.secondary)
                .font(.headline)
        }
    }
}

#Preview {
    LicenseSettingsView()
        .frame(width: 500, height: 600)
}
