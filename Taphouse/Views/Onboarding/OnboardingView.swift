import SwiftUI

/// Onboarding view shown when Homebrew is not installed or on first launch
struct OnboardingView: View {
    @Environment(\.openURL) private var openURL
    @State private var currentStep = 0
    @State private var isCheckingInstallation = false
    @State private var installCommand = "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""

    var onComplete: () -> Void

    private let steps = [
        OnboardingStep(
            title: "Welcome to Taphouse",
            description: "The native macOS app for managing your Homebrew packages with ease.",
            systemImage: "mug.fill",
            color: .orange
        ),
        OnboardingStep(
            title: "Homebrew Required",
            description: "Taphouse needs Homebrew to be installed on your Mac. It's free and takes just a minute.",
            systemImage: "shippingbox.fill",
            color: .blue
        ),
        OnboardingStep(
            title: "Install Homebrew",
            description: "Open Terminal and paste the installation command, or click the button below to visit brew.sh",
            systemImage: "terminal.fill",
            color: .green
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)

            Spacer()

            // Current step content
            VStack(spacing: 24) {
                Image(systemName: steps[currentStep].systemImage)
                    .font(.system(size: 80))
                    .foregroundStyle(steps[currentStep].color)
                    .symbolEffect(.bounce, value: currentStep)

                Text(steps[currentStep].title)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(steps[currentStep].description)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)

                // Step-specific content
                if currentStep == 2 {
                    installationStepContent
                }
            }
            .padding(40)

            Spacer()

            // Navigation buttons
            HStack(spacing: 16) {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if currentStep < steps.count - 1 {
                    Button("Next") {
                        withAnimation {
                            currentStep += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        checkInstallation()
                    } label: {
                        if isCheckingInstallation {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Check Installation")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isCheckingInstallation)
                }
            }
            .padding(40)
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var installationStepContent: some View {
        VStack(spacing: 16) {
            // Install command box
            HStack {
                Text(installCommand)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Button {
                    copyCommand()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")
            }
            .padding(12)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )

            HStack(spacing: 16) {
                Button {
                    copyCommand()
                    openTerminal()
                } label: {
                    Label("Open Terminal", systemImage: "terminal")
                }
                .buttonStyle(.bordered)

                Button {
                    openURL(URL(string: "https://brew.sh")!)
                } label: {
                    Label("Visit brew.sh", systemImage: "safari")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func copyCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(installCommand, forType: .string)
    }

    private func openTerminal() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private func checkInstallation() {
        isCheckingInstallation = true

        Task {
            // Check if brew is now available
            let pathResolver = BrewPathResolver()
            let brewPath = await pathResolver.resolve()

            await MainActor.run {
                isCheckingInstallation = false

                if brewPath != nil {
                    onComplete()
                } else {
                    // Show alert that Homebrew is still not found
                    let alert = NSAlert()
                    alert.messageText = "Homebrew Not Found"
                    alert.informativeText = "Homebrew doesn't seem to be installed yet. Please complete the installation in Terminal and try again."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
}

struct OnboardingStep {
    let title: String
    let description: String
    let systemImage: String
    let color: Color
}

#Preview {
    OnboardingView {
        print("Onboarding complete")
    }
}
