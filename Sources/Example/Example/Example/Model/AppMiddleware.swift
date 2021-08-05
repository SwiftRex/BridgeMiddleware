import AppLifecycleMiddleware
import BridgeMiddlewareCombine
import CombineRex
import Foundation
import LoggerMiddleware
import ReachabilityMiddleware

extension AnyMiddleware where InputActionType == AppAction, OutputActionType == AppAction, StateType == AppState {
    static func app(world: World) -> ComposedMiddleware<AppAction, AppAction, AppState> {
        EffectMiddleware<ReachabilityEvent, ReachabilityEvent, ReachabilityState, ReachabilityMiddlewareDependencies>
            .reachability
            .inject(ReachabilityMiddlewareDependencies(pathMonitor: world.pathMonitor))
            .lift(action: \AppAction.reachability, state: \AppState.reachability)

        <> AppLifecycleMiddleware(publisher: world.lifecycleNotificationCenter)
            .lift(inputAction: { _ in nil }, outputAction: AppAction.lifecycle, state: ignore)

        <> BridgeMiddleware.lifecycleToReachabilityActions

            <> IdentityMiddleware<AppAction, AppAction, AppState>().logger(
                actionTransform: .custom { action, source in
                    String(
                        """
                        
                        ┌─▶ \(action)
                        │ source: \(source.file):\(source.line)
                        │ function: \(source.function)
                        │ info: \(source.info ?? "<nil>")
                        └────────────────────
                        """
                    )
                },
                stateDiffTransform: .custom { _, _ in nil },
                queue: .main
            )
    }
}
