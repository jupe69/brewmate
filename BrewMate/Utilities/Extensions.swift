import Foundation
import SwiftUI

// MARK: - String Extensions

extension String {
    /// Truncates the string to a maximum length with ellipsis
    func truncated(to maxLength: Int) -> String {
        if count <= maxLength {
            return self
        }
        return String(prefix(maxLength - 1)) + "…"
    }

    /// Removes ANSI color codes from terminal output
    var strippingANSICodes: String {
        let pattern = #"\u{001B}\[[0-9;]*m"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return self
        }
        let range = NSRange(startIndex..., in: self)
        return regex.stringByReplacingMatches(in: self, range: range, withTemplate: "")
    }
}

// MARK: - View Extensions

extension View {
    /// Apply a modifier conditionally
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Add keyboard shortcut with modifier
    func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command, action: @escaping () -> Void) -> some View {
        self.background(
            Button("") {
                action()
            }
            .keyboardShortcut(key, modifiers: modifiers)
            .opacity(0)
        )
    }
}

// MARK: - Date Extensions

extension Date {
    /// Format date as relative time (e.g., "2 days ago")
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// Format date as "MMM d, yyyy"
    var shortFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}

// MARK: - Array Extensions

extension Array where Element: Identifiable {
    /// Find element by ID
    func find(id: Element.ID) -> Element? {
        first { $0.id == id }
    }
}

// MARK: - Color Extensions

extension Color {
    /// Color for service status indicators
    static func serviceStatus(_ status: BrewServiceInfo.ServiceStatus) -> Color {
        switch status {
        case .running: return .green
        case .stopped: return .gray
        case .error: return .red
        case .scheduled: return .blue
        case .unknown, .none: return .secondary
        }
    }
}

// MARK: - URL Extensions

extension URL {
    /// Open URL in default browser
    func openInBrowser() {
        NSWorkspace.shared.open(self)
    }
}

// MARK: - Task Extensions

extension Task where Success == Never, Failure == Never {
    /// Sleep for a given number of seconds
    static func sleep(seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
