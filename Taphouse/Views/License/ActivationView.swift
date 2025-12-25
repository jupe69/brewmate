import SwiftUI

/// View for entering and activating a license key
struct ActivationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var licenseKey: String = ""
    @State private var isActivating = false
    @State private var error: String?
    @State private var showSuccess = false

    private var licenseManager: LicenseManager { LicenseManager.shared }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("Activate Taphouse Pro")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Enter your license key to unlock all Pro features")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // License key input
            VStack(alignment: .leading, spacing: 8) {
                Text("License Key")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX", text: $licenseKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .onSubmit {
                        if !licenseKey.isEmpty && !isActivating {
                            Task { await activate() }
                        }
                    }
            }

            // Error message
            if let error = error {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .foregroundStyle(.red)
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Actions
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    Task { await activate() }
                } label: {
                    if isActivating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Activate")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(licenseKey.trimmingCharacters(in: .whitespaces).isEmpty || isActivating)
                .keyboardShortcut(.defaultAction)
            }

            Divider()

            // Purchase link
            HStack(spacing: 4) {
                Text("Don't have a license?")
                    .foregroundStyle(.secondary)

                Button("Purchase Taphouse Pro") {
                    openURL(LicenseManager.purchaseURL)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }
            .font(.caption)
        }
        .padding(32)
        .frame(width: 420)
        .alert("Activation Successful", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Taphouse Pro has been activated. Enjoy all the Pro features!")
        }
    }

    private func activate() async {
        isActivating = true
        error = nil

        do {
            try await licenseManager.activateLicense(key: licenseKey)
            showSuccess = true
        } catch let licenseError as LicenseError {
            error = licenseError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }

        isActivating = false
    }
}

#Preview {
    ActivationView()
}
