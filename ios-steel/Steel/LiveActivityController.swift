import Foundation
import ActivityKit

@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()

    private var activity: Activity<SteelActivityAttributes>?

    private init() {}

    func start() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let progress = DataManager.shared.taskProgress
        let state = SteelActivityAttributes.ContentState(done: progress.done, total: progress.total)
        let attributes = SteelActivityAttributes(title: "Сегодня")
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
        } catch {
            activity = nil
        }
    }

    func refresh() {
        let progress = DataManager.shared.taskProgress
        guard progress.total > 0 else {
            Task { await end() }
            return
        }
        if activity == nil {
            start()
            return
        }
        let state = SteelActivityAttributes.ContentState(done: progress.done, total: progress.total)
        Task { await activity?.update(.init(state: state, staleDate: nil)) }
    }

    func end() async {
        await activity?.end(nil, dismissalPolicy: .immediate)
        activity = nil
    }
}
