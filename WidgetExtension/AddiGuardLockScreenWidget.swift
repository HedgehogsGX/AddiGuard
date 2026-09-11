import SwiftUI
import WidgetKit

private struct AddiGuardWidgetEntry: TimelineEntry {
    let date: Date
}

private struct AddiGuardWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> AddiGuardWidgetEntry {
        AddiGuardWidgetEntry(date: .now)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (AddiGuardWidgetEntry) -> Void
    ) {
        completion(AddiGuardWidgetEntry(date: .now))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<AddiGuardWidgetEntry>) -> Void
    ) {
        let entry = AddiGuardWidgetEntry(date: .now)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

private struct AddiGuardLockScreenWidgetView: View {
    @Environment(\.widgetFamily) private var family

    private let scanURL = URL(string: "addiguard://scan")

    var body: some View {
        content
            .containerBackground(for: .widget) {
                Color.clear
            }
            .widgetURL(scanURL)
            .accessibilityLabel("打开 AddiGuard 扫描食品配料")
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Label("扫描食品添加剂", systemImage: "checkmark.shield.fill")

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title3.weight(.semibold))
                        .widgetAccentable()
                    Text("扫描")
                        .font(.caption2.weight(.bold))
                }
            }

        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.title2.weight(.semibold))
                    .widgetAccentable()

                VStack(alignment: .leading, spacing: 1) {
                    Text("扫描配料")
                        .font(.headline)
                    Text("识别食品添加剂")
                        .font(.caption)
                }
                .minimumScaleFactor(0.8)

                Spacer(minLength: 0)
            }

        default:
            EmptyView()
        }
    }
}

@main
struct AddiGuardLockScreenWidget: Widget {
    private let kind = "AddiGuardLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AddiGuardWidgetProvider()) { _ in
            AddiGuardLockScreenWidgetView()
        }
        .configurationDisplayName("快速扫描配料")
        .description("从锁定屏幕打开 AddiGuard，识别食品配料表中的添加剂。")
        .supportedFamilies([
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular,
        ])
    }
}
