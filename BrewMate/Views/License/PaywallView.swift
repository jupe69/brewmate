import SwiftUI

/// Upgrade prompt shown when accessing Pro features without a license
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showActivation = false

    let feature: ProFeature

    private var licenseManager: LicenseManager { LicenseManager.shared }

    var body: some View {
        VStack(spacing: 24) {
            // Pro badge
            proBadge

            // Title
            Text("Upgrade to Pro")
                .font(.title)
                .fontWeight(.bold)

            // Feature being accessed
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: feature.systemImage)
                        .foregroundStyle(.blue)
                    Text(feature.name)
                        .fontWeight(.semibold)
                }
                .font(.headline)

                Text(feature.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            // Trial status
            if let daysRemaining = licenseManager.trialDaysRemaining, daysRemaining > 0 {
                trialBadge(daysRemaining: daysRemaining)
            } else if licenseManager.licenseStatus == .expired {
                expiredBadge
            }

            // All Pro features list
            proFeaturesList

            // Price
            VStack(spacing: 4) {
                Text("$4.99")
                    .font(.system(size: 36, weight: .bold))
                Text("One-time purchase")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Actions
            VStack(spacing: 12) {
                Button {
                    openURL(LicenseManager.purchaseURL)
                } label: {
                    Text("Purchase Pro")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("I have a license key") {
                    showActivation = true
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }
            .frame(maxWidth: 280)

            Button("Maybe Later") {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        }
        .padding(32)
        .frame(width: 400)
        .sheet(isPresented: $showActivation) {
            ActivationView()
        }
    }

    private var proBadge: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 80, height: 80)

            Image(systemName: "crown.fill")
                .font(.system(size: 36))
                .foregroundStyle(.white)
        }
    }

    private func trialBadge(daysRemaining: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .foregroundStyle(.orange)
            Text("\(daysRemaining) day\(daysRemaining == 1 ? "" : "s") left in trial")
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.15))
        .clipShape(Capsule())
    }

    private var expiredBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text("Trial expired")
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.15))
        .clipShape(Capsule())
    }

    private var proFeaturesList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(ProFeature.allCases) { proFeature in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(proFeature.name)
                        .font(.subheadline)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// A compact inline paywall for embedding in views
struct InlinePaywallView: View {
    let feature: ProFeature
    @State private var showFullPaywall = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("\(feature.name) is a Pro feature")
                .font(.headline)

            Text(feature.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Upgrade to Pro") {
                showFullPaywall = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showFullPaywall) {
            PaywallView(feature: feature)
        }
    }
}

#Preview("Paywall") {
    PaywallView(feature: .brewfile)
}

#Preview("Inline Paywall") {
    InlinePaywallView(feature: .cleanup)
        .frame(width: 400, height: 400)
}
