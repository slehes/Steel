import Foundation
import ActivityKit

struct SteelActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var done: Int
        var total: Int
    }

    var title: String
}
