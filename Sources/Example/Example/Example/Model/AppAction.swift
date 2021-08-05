import AppLifecycleMiddleware
import Foundation
import ReachabilityMiddleware

enum AppAction {
    case reachability(ReachabilityEvent)
    case lifecycle(AppLifecycleAction)
}
