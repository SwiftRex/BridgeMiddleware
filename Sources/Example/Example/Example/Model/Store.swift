import CombineRex

class Store: ReduxStoreBase<AppAction, AppState> {
    init(world: World) {
        super.init(
            subject: .combine(initialValue: .initial),
            reducer: Reducer.app,
            middleware: AnyMiddleware.app(world: world)
        )
    }
}
