import Foundation
import BridgeMiddlewareCombine

extension BridgeMiddleware where InputActionType == AppAction, OutputActionType == AppAction, StateType == AppState {
    static let lifecycleToReachabilityActions: BridgeMiddleware =
        BridgeMiddleware()
            .bridge(\AppAction.lifecycle?.didBecomeActive --> AppAction.reachability(.startMonitoring))
            .bridge(\AppAction.lifecycle?.didEnterBackground --> AppAction.reachability(.stopMonitoring))
}
