import AppLifecycleMiddleware
import Foundation
import ReachabilityMiddleware

struct AppState: Equatable {
    var reachability: ReachabilityState
    var lifecycle: AppLifecycle

    static var initial: AppState {
        .init(reachability: .initial, lifecycle: .backgroundInactive)
    }
}
