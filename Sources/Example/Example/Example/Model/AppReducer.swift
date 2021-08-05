import AppLifecycleMiddleware
import Foundation
import ReachabilityMiddleware
import SwiftRex

extension Reducer where ActionType == AppAction, StateType == AppState {
    static let app: Reducer =
        Reducer<ReachabilityEvent, ReachabilityState>
            .reachability
            .lift(action: \AppAction.reachability, state: \AppState.reachability)
        <> Reducer<AppLifecycleAction, AppLifecycle>
            .lifecycle
            .lift(action: \AppAction.lifecycle, state: \AppState.lifecycle)
}
