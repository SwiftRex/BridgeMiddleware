import Foundation
import SwiftRex

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension BridgeMiddleware where StateType: Identifiable {
    public func liftToCollection<GlobalAction, GlobalState, CollectionState: MutableCollection>(
        inputAction actionMap: @escaping (GlobalAction) -> ElementIDAction<StateType.ID, InputActionType>?,
        outputAction outputMap: @escaping (ElementIDAction<StateType.ID, OutputActionType>) -> GlobalAction,
        stateCollection: @escaping (GlobalState) -> CollectionState
    ) -> BridgeMiddleware<GlobalAction, GlobalAction, GlobalState> where CollectionState.Element == StateType {
        let mw = BridgeMiddleware<GlobalAction, GlobalAction, GlobalState>()
        self.bridges.forEach { bridge in
            mw.bridges.append(
                BridgeMiddleware<GlobalAction, GlobalAction, GlobalState>.Bridge(
                    actionTransformation: { (globalInputAction: GlobalAction) -> GlobalAction? in
                        guard let localElementIDInputAction = actionMap(globalInputAction),
                              let localOutputAction = bridge.actionTransformation(localElementIDInputAction.action)
                        else { return nil }

                        return outputMap(.init(id: localElementIDInputAction.id, action: localOutputAction))
                    },
                    statePredicate: { (getState: GetState<GlobalState>, action: GlobalAction) -> Bool in
                        guard let itemAction = actionMap(action),
                              let itemState = stateCollection(getState()).first(where: { $0.id == itemAction.id })
                        else { return false }

                        return bridge.statePredicate({ itemState }, itemAction.action)
                    },
                    bridgedAtSource: bridge.bridgedAtSource
                )
            )
        }
        return mw
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension BridgeMiddleware where StateType: Identifiable, InputActionType == OutputActionType {
    public func liftToCollection<GlobalAction, GlobalState, CollectionState: MutableCollection>(
        action actionMap: WritableKeyPath<GlobalAction, ElementIDAction<StateType.ID, InputActionType>?>,
        stateCollection: KeyPath<GlobalState, CollectionState>
    ) -> BridgeMiddleware<GlobalAction, GlobalAction, GlobalState> where CollectionState.Element == StateType {
        let mw = BridgeMiddleware<GlobalAction, GlobalAction, GlobalState>()
        self.bridges.forEach { bridge in
            mw.bridges.append(
                BridgeMiddleware<GlobalAction, GlobalAction, GlobalState>.Bridge(
                    actionTransformation: { (globalInputAction: GlobalAction) -> GlobalAction? in
                        guard let localElementIDInputAction = globalInputAction[keyPath: actionMap],
                              let localOutputAction = bridge.actionTransformation(localElementIDInputAction.action)
                        else { return nil }

                        var newAction = globalInputAction
                        newAction[keyPath: actionMap] = .init(id: localElementIDInputAction.id, action: localOutputAction)
                        return newAction
                    },
                    statePredicate: { (getState: GetState<GlobalState>, action: GlobalAction) -> Bool in
                        guard let itemAction = action[keyPath: actionMap],
                              let itemState = getState()[keyPath: stateCollection].first(where: { $0.id == itemAction.id })
                        else { return false }

                        return bridge.statePredicate({ itemState }, itemAction.action)
                    },
                    bridgedAtSource: bridge.bridgedAtSource
                )
            )
        }
        return mw
    }
}
