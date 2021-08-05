# BridgeMiddleware

A middleware to bridge original actions into derived actions and connect different modules

If you have a Middleware taking care of a small piece in your AppState / AppAction, and another Middleware taking care of a completely
different part of your AppState / AppAction, and eventually you want these two middlewares to "exchange" messages, that would mean either:
- change the first Middleware to use a broader AppAction for Input Action, or Output Action, or both; or
- change the second Middleware as said before
- change both (no, please, no...)
- create a Middleware to take care of the "glue" between the previous two.

Although each of these approaches may offer advantages and drawbacks, usually making a middleware taking care of a more broad piece of state
or action seems to violate its boundaries, allowing it to handle multiple different domains and breaking its single responsibility. Sometimes
this also may involve changing your switch/case for the action to take care of a LOT of different things that are mostly irrelevant for this
middleware. If you use "default", then you create a blind spot where relevant actions could be ignored and bugs introduced.

Creating a middleware between them seems to be the most appropriate option, usually. For example, you want to start monitoring your
reachability when your app is in foreground, and stop when your app is in background. The
[AppLifecycle Middleware](https://github.com/SwiftRex/AppLifecycleMiddleware) can give you `AppLifecycleAction.didBecomeActive`, for which you
want to dispatch `ReachabilityEvent.startMonitoring` on [Reachability Middleware](https://github.com/SwiftRex/ReachabilityMiddleware). But you
don't control either of these Middlewares, and they operate on completely different generic types, right?

You can use Bridge Middleware exactly in such scenarios, keeping your middlewares isolated from each other, taking care of their own businesses,
and these bridges will hold the general business workflow of your app. You can have multiple Bridge Middlewares, and each one can have one or
multiple bridges.

```swift
static let lifecycleToReachabilityActions: BridgeMiddleware =
    BridgeMiddleware()
        .bridge(\AppAction.lifecycle?.didBecomeActive --> AppAction.reachability(.startMonitoring))
        .bridge(\AppAction.lifecycle?.didEnterBackground --> AppAction.reachability(.stopMonitoring))
```

In this example, every time your app becomes active, reachability will start monitoring the internet, and when the app enters background,
reachability will stop monitoring. The full example can be seen in the [Sources](Sources/Example) folder of this repository. When running
this example, if you watch the logs you're gonna see something like this:

```
┌─▶ lifecycle(AppLifecycleMiddleware.AppLifecycleAction.willEnterForeground)
│ source: AppLifecycleMiddleware/AppLifecycleMiddleware.swift:118
│ function: receiveContext(getState:output:)
│ info: <nil>
└────────────────────

┌─▶ lifecycle(AppLifecycleMiddleware.AppLifecycleAction.didBecomeActive)
│ source: AppLifecycleMiddleware/AppLifecycleMiddleware.swift:118
│ function: receiveContext(getState:output:)
│ info: <nil>
└────────────────────

┌─▶ reachability(ReachabilityMiddleware.ReachabilityEvent.startMonitoring)
│ source: AppLifecycleMiddleware/AppLifecycleMiddleware.swift:118
│ function: receiveContext(getState:output:)
│ info: Bridged from lifecycle(AppLifecycleMiddleware.AppLifecycleAction.didBecomeActive) at BridgeLifecycleToReachability.swift, BridgeMiddleware:7
└────────────────────

┌─▶ reachability(ReachabilityMiddleware.ReachabilityEvent.connectedToWired)
│ source: ReachabilityMiddleware/ReachabilityMiddleware.swift:21
│ function: reachability
│ info: <nil>
└────────────────────

┌─▶ reachability(ReachabilityMiddleware.ReachabilityEvent.becameCheap)
│ source: ReachabilityMiddleware/ReachabilityMiddleware.swift:46
│ function: reachability
│ info: <nil>
└────────────────────

┌─▶ reachability(ReachabilityMiddleware.ReachabilityEvent.becameUnconstrained)
│ source: ReachabilityMiddleware/ReachabilityMiddleware.swift:56
│ function: reachability
│ info: <nil>
└────────────────────

┌─▶ lifecycle(AppLifecycleMiddleware.AppLifecycleAction.willBecomeInactive)
│ source: AppLifecycleMiddleware/AppLifecycleMiddleware.swift:118
│ function: receiveContext(getState:output:)
│ info: <nil>
└────────────────────

┌─▶ lifecycle(AppLifecycleMiddleware.AppLifecycleAction.didEnterBackground)
│ source: AppLifecycleMiddleware/AppLifecycleMiddleware.swift:118
│ function: receiveContext(getState:output:)
│ info: <nil>
└────────────────────

┌─▶ reachability(ReachabilityMiddleware.ReachabilityEvent.stopMonitoring)
│ source: AppLifecycleMiddleware/AppLifecycleMiddleware.swift:118
│ function: receiveContext(getState:output:)
│ info: Bridged from lifecycle(AppLifecycleMiddleware.AppLifecycleAction.didEnterBackground) at BridgeLifecycleToReachability.swift, BridgeMiddleware:8
└────────────────────

┌─▶ lifecycle(AppLifecycleMiddleware.AppLifecycleAction.willEnterForeground)
│ source: AppLifecycleMiddleware/AppLifecycleMiddleware.swift:118
│ function: receiveContext(getState:output:)
│ info: <nil>
└────────────────────

┌─▶ lifecycle(AppLifecycleMiddleware.AppLifecycleAction.didBecomeActive)
│ source: AppLifecycleMiddleware/AppLifecycleMiddleware.swift:118
│ function: receiveContext(getState:output:)
│ info: <nil>
└────────────────────

┌─▶ reachability(ReachabilityMiddleware.ReachabilityEvent.startMonitoring)
│ source: AppLifecycleMiddleware/AppLifecycleMiddleware.swift:118
│ function: receiveContext(getState:output:)
│ info: Bridged from lifecycle(AppLifecycleMiddleware.AppLifecycleAction.didBecomeActive) at BridgeLifecycleToReachability.swift, BridgeMiddleware:7
└────────────────────

┌─▶ reachability(ReachabilityMiddleware.ReachabilityEvent.connectedToWired)
│ source: ReachabilityMiddleware/ReachabilityMiddleware.swift:21
│ function: reachability
│ info: <nil>
└────────────────────

┌─▶ reachability(ReachabilityMiddleware.ReachabilityEvent.becameCheap)
│ source: ReachabilityMiddleware/ReachabilityMiddleware.swift:46
│ function: reachability
│ info: <nil>
└────────────────────

┌─▶ reachability(ReachabilityMiddleware.ReachabilityEvent.becameUnconstrained)
│ source: ReachabilityMiddleware/ReachabilityMiddleware.swift:56
│ function: reachability
│ info: <nil>
└────────────────────
```

Under "info" String of your ActionSource, you can see the information about the original action, and the file, line and function that bridged the action.
The ActionSource of the new action is kept as the original one, not the bridge, as if the bridge didn't exist. That it's probably better for debugging the
flow of a complex app.

## Filter by State

You can optionally filter by State, in case you want to dispatch the derived action only when certain state can be observed. There are two options, receiving
a closure such as `{ getState in getState().qa.theStateOfSomething == .active }`, or a KeyPath to a Bool, such as `\AppState.qa.isSomethingEnabled`. The state
is evaluated AFTER the reducer, so the original action will first mutate the state, then the bridge will evaluate it and either dispatch or not the derived
action according to this predicate.

With closure:
```swift
static let lifecycleToReachabilityActions: BridgeMiddleware =
    BridgeMiddleware()
        .bridge(\AppAction.lifecycle?.didBecomeActive --> AppAction.reachability(.startMonitoring), when: { $0().settings.reachabilityOptions == .always })
        .bridge(\AppAction.lifecycle?.didEnterBackground --> AppAction.reachability(.stopMonitoring), when: { $0().settings.reachabilityOptions == .always })
```

With KeyPath:
```swift
static let lifecycleToReachabilityActions: BridgeMiddleware =
    BridgeMiddleware()
        .bridge(\AppAction.lifecycle?.didBecomeActive --> AppAction.reachability(.startMonitoring), when: \.settings.shouldUseReachability)
        .bridge(\AppAction.lifecycle?.didEnterBackground --> AppAction.reachability(.stopMonitoring), when: \.settings.shouldUseReachability)
```
