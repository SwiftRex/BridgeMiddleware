import CombineRex
import SwiftUI
import Network

extension World {
    fileprivate static let live: World = World(
        pathMonitor: { NWPathMonitor().publisher.eraseToAnyPublisher() },
        lifecycleNotificationCenter: NotificationCenter.default
    )
}

@main
struct ExampleApp: App {
    private static let world = World.live
    @StateObject var store = Store(world: world).asObservableViewModel(initialState: .initial)

    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: store
                    .projection(action: \.toAppAction, state: ContentViewState.from(appState:))
                    .asObservableViewModel(initialState: .empty)
            )
        }
    }
}
