import WidgetKit
import SwiftUI

nonisolated struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
}

nonisolated struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: .now, streak: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(StreakEntry(date: .now, streak: SharedStore.streak))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let entry = StreakEntry(date: .now, streak: SharedStore.streak)
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(1800))))
    }
}

struct StreakWidgetView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: "flame.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Text("\(entry.streak)")
                .font(.system(size: 52, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
            Text("дней подряд")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            Color.black
        }
    }
}

struct SteelWidget: Widget {
    let kind: String = "SteelWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Серия Steel")
        .description("Дни подряд без пропусков.")
        .supportedFamilies([.systemSmall])
    }
}
