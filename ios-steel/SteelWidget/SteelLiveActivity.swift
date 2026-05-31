import WidgetKit
import SwiftUI
import ActivityKit

struct SteelLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SteelActivityAttributes.self) { context in
            HStack(spacing: 16) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    ProgressView(value: ratio(context.state))
                        .tint(.white)
                }
                Text("\(context.state.done)/\(context.state.total)")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding()
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.done)/\(context.state.total)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: ratio(context.state))
                        .tint(.white)
                }
            } compactLeading: {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.white)
            } compactTrailing: {
                Text("\(context.state.done)/\(context.state.total)")
                    .foregroundStyle(.white)
            } minimal: {
                Text("\(context.state.done)")
                    .foregroundStyle(.white)
            }
        }
    }

    private func ratio(_ state: SteelActivityAttributes.ContentState) -> Double {
        state.total > 0 ? Double(state.done) / Double(state.total) : 0
    }
}
