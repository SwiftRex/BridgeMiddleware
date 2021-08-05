import AppLifecycleMiddleware
import Foundation
import ReachabilityMiddleware

extension AppAction {
    public var reachability: ReachabilityEvent? {
        get {
            guard case let .reachability(value) = self else { return nil }
            return value
        }
        set {
            guard case .reachability = self, let newValue = newValue else { return }
            self = .reachability(newValue)
        }
    }

    public var isReachability: Bool {
        self.reachability != nil
    }
}

extension AppAction {
    public var lifecycle: AppLifecycleAction? {
        get {
            guard case let .lifecycle(value) = self else { return nil }
            return value
        }
        set {
            guard case .lifecycle = self, let newValue = newValue else { return }
            self = .lifecycle(newValue)
        }
    }

    public var isAppLifecycleAction: Bool {
        self.lifecycle != nil
    }
}
