import CombineRex
import SwiftUI

struct ContentViewState: Equatable {
    static func from(appState: AppState) -> ContentViewState {
        .init()
    }

    static var empty: ContentViewState {
        .init()
    }
}

enum ContentViewAction {
    var toAppAction: AppAction? {
        switch self {
        
        }
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: ObservableViewModel<ContentViewAction, ContentViewState>

    var body: some View {
        Text("Nothing to see here, please watch your logs")
            .padding()
    }
}
