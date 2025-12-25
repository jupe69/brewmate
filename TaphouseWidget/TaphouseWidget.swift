import WidgetKit
import SwiftUI

/// Data shared between the main app and widget
struct WidgetData: Codable {
    let outdatedCount: Int
    let outdatedPackages: [String]
    let lastUpdated: Date

    static let empty = WidgetData(outdatedCount: 0, outdatedPackages: [], lastUpdated: Date())

    static func load() -> WidgetData {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.multimodalsolutions.taphouse"
        ) else {
            return .empty
        }

        let fileURL = containerURL.appendingPathComponent("widget_data.json")

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(WidgetData.self, from: data)
        } catch {
            return .empty
        }
    }
}

/// Timeline entry for the widget
struct WidgetEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

/// Timeline provider that determines when the widget updates
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), data: WidgetData(outdatedCount: 3, outdatedPackages: ["git", "node", "python"], lastUpdated: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        let entry = WidgetEntry(date: Date(), data: WidgetData.load())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let currentDate = Date()
        let data = WidgetData.load()
        let entry = WidgetEntry(date: currentDate, data: data)

        // Update widget every hour
        let nextUpdateDate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
        completion(timeline)
    }
}

/// Small widget view
struct SmallWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: entry.data.outdatedCount > 0 ? "arrow.up.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(entry.data.outdatedCount > 0 ? .orange : .green)

            if entry.data.outdatedCount > 0 {
                Text("\(entry.data.outdatedCount)")
                    .font(.title)
                    .fontWeight(.bold)

                Text("updates")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Up to date")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

/// Medium widget view
struct MediumWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left side - count
            VStack(spacing: 4) {
                Image(systemName: entry.data.outdatedCount > 0 ? "arrow.up.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(entry.data.outdatedCount > 0 ? .orange : .green)

                if entry.data.outdatedCount > 0 {
                    Text("\(entry.data.outdatedCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("updates")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("All good!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80)

            Divider()

            // Right side - package list
            if entry.data.outdatedCount > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(entry.data.outdatedPackages.prefix(4), id: \.self) { package in
                        HStack(spacing: 6) {
                            Image(systemName: "shippingbox.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Text(package)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }

                    if entry.data.outdatedPackages.count > 4 {
                        Text("+\(entry.data.outdatedPackages.count - 4) more")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("All packages are up to date!")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Last checked: \(entry.data.lastUpdated.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

/// Large widget view
struct LargeWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "mug.fill")
                    .foregroundStyle(.orange)
                Text("Taphouse")
                    .font(.headline)

                Spacer()

                if entry.data.outdatedCount > 0 {
                    Text("\(entry.data.outdatedCount) updates")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                } else {
                    Text("Up to date")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }

            Divider()

            // Package list
            if entry.data.outdatedCount > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.data.outdatedPackages.prefix(8), id: \.self) { package in
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text(package)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                        }
                    }

                    if entry.data.outdatedPackages.count > 8 {
                        Text("+\(entry.data.outdatedPackages.count - 8) more packages")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
            } else {
                VStack(alignment: .center, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green)

                    Text("All packages are up to date!")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Spacer()

            // Footer
            Text("Last checked: \(entry.data.lastUpdated.formatted(.relative(presentation: .named)))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

/// Main widget entry view
struct TaphouseWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

/// The main widget definition
@main
struct TaphouseWidget: Widget {
    let kind: String = "TaphouseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            TaphouseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Taphouse Updates")
        .description("Shows outdated Homebrew packages")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview("Small", as: .systemSmall) {
    TaphouseWidget()
} timeline: {
    WidgetEntry(date: .now, data: WidgetData(outdatedCount: 5, outdatedPackages: ["git", "node", "python", "rust", "go"], lastUpdated: Date()))
    WidgetEntry(date: .now, data: WidgetData(outdatedCount: 0, outdatedPackages: [], lastUpdated: Date()))
}

#Preview("Medium", as: .systemMedium) {
    TaphouseWidget()
} timeline: {
    WidgetEntry(date: .now, data: WidgetData(outdatedCount: 5, outdatedPackages: ["git", "node", "python", "rust", "go"], lastUpdated: Date()))
}

#Preview("Large", as: .systemLarge) {
    TaphouseWidget()
} timeline: {
    WidgetEntry(date: .now, data: WidgetData(outdatedCount: 10, outdatedPackages: ["git", "node", "python", "rust", "go", "ruby", "php", "java", "kotlin", "swift"], lastUpdated: Date()))
}
