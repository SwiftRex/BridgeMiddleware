import AppLifecycleMiddleware
import Combine
import Foundation
import Network
import ReachabilityMiddleware

struct World {
    let pathMonitor: () -> AnyPublisher<NWPathProtocol, Never>
    let lifecycleNotificationCenter: NotificationPublisher
}
