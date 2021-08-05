import Foundation
import SwiftRex

infix operator -->: KeyPathComposition
precedencegroup KeyPathComposition {
    associativity: left
    lowerThan: AssignmentPrecedence
}

public struct ArrowMap<In, Value, Out> {
    public init(valueIn: KeyPath<In, Value?>, valueOut: @escaping (Value) -> Out?) {
        self.valueIn = valueIn
        self.valueOut = valueOut
    }

    public let valueIn: KeyPath<In, Value?>
    public let valueOut: (Value) -> Out?
}

public func --> <In, Value, Out>(_ in: KeyPath<In, Value?>, _ out: @escaping (Value) -> Out?) -> ArrowMap<In, Value, Out> {
    .init(valueIn: `in`, valueOut: out)
}

public func --> <In, Value, Out>(_ in: KeyPath<In, Value?>, _ out: Out) -> ArrowMap<In, Value, Out> {
    .init(valueIn: `in`, valueOut: { _ in out })
}

public class BridgeMiddleware<InputActionType, OutputActionType, StateType>: Middleware {
    struct Bridge {
        let actionTransformation: (InputActionType) -> OutputActionType?
        let statePredicate: (GetState<StateType>) -> Bool
        let bridgedAtSource: ActionSource
    }

    private var bridges: [Bridge] = []

    public init() { }

    /// Bridge an action to another derived action
    ///
    /// - Parameters:
    ///   - mapping: an arrow from KeyPath resolving and filtering incoming actions to filter for one in particular, to a derived action,
    ///              such as in `\AppAction.some?.tree?.myObservedAction --> AppAction.another(.tree(.myDerivedAction))`. Please notice only
    ///              the left part is KeyPath. If you want to transfer some associated value from the original to the derived action, this is
    ///              possible either using closure: `\AppAction.some?.tree?.myObservedAction --> { AppAction.another(.tree(.myDerivedAction($0))) }`
    ///              where `$0` is whatever `myObservedAction` holds, or using function composition:
    ///              `\AppAction.some?.tree?.myObservedAction --> SomethingInTree.myDerivedAction >>> Another.tree >>> AppAction.another`
    ///   - stateAfterReducerPredicate: optional filter in case the state (after reducer) is not the way you want, for example:
    ///                                 `{ getState in getState().qa.theStateOfSomething == .active }`
    ///   - file: file where the bridge happens, most of the times you want this to default to #file
    ///   - line: line where the bridge happens, most of the times you want this to default to #line
    ///   - function: function where the bridge happens, most of the times you want this to default to #function
    /// - Returns: The instance of this middleware itself, modified with the new bridge
    public func bridge<Value>(
        _ mapping: ArrowMap<InputActionType, Value, OutputActionType>,
        when stateAfterReducerPredicate: @escaping (GetState<StateType>) -> Bool = { _ in true },
        file: String = #file,
        line: UInt = #line,
        function: String = #function
    ) -> BridgeMiddleware {
        on(mapping.valueIn, dispatch: mapping.valueOut, when: stateAfterReducerPredicate, file: file, line: line, function: function)
    }

    /// Bridge an action to another derived action
    ///
    /// - Parameters:
    ///   - mapping: an arrow from KeyPath resolving and filtering incoming actions to filter for one in particular, to a derived action,
    ///              such as in `\AppAction.some?.tree?.myObservedAction --> AppAction.another(.tree(.myDerivedAction))`. Please notice only
    ///              the left part is KeyPath. If you want to transfer some associated value from the original to the derived action, this is
    ///              possible either using closure: `\AppAction.some?.tree?.myObservedAction --> { AppAction.another(.tree(.myDerivedAction($0))) }`
    ///              where `$0` is whatever `myObservedAction` holds, or using function composition:
    ///              `\AppAction.some?.tree?.myObservedAction --> SomethingInTree.myDerivedAction >>> Another.tree >>> AppAction.another`
    ///   - stateAfterReducerPredicate: filter using KeyPath in case the state (after reducer) is not the way you want, for example:
    ///                                 `\AppState.qa.isSomethingEnabled`
    ///   - file: file where the bridge happens, most of the times you want this to default to #file
    ///   - line: line where the bridge happens, most of the times you want this to default to #line
    ///   - function: function where the bridge happens, most of the times you want this to default to #function
    /// - Returns: The instance of this middleware itself, modified with the new bridge
    public func bridge<Value>(
        _ mapping: ArrowMap<InputActionType, Value, OutputActionType>,
        when stateAfterReducerPredicate: KeyPath<StateType, Bool>,
        file: String = #file,
        line: UInt = #line,
        function: String = #function
    ) -> BridgeMiddleware {
        on(
            mapping.valueIn,
            dispatch: mapping.valueOut,
            when: { $0()[keyPath: stateAfterReducerPredicate] },
            file: file,
            line: line,
            function: function
        )
    }

    private func on<Value>(
        _ keyPathChecker: KeyPath<InputActionType, Value?>,
        dispatch outputAction: @escaping (Value) -> OutputActionType?,
        when stateAfterReducerPredicate: @escaping (GetState<StateType>) -> Bool = { _ in true },
        file: String = #file,
        line: UInt = #line,
        function: String = #function
    ) -> BridgeMiddleware {
        bridges.append(
            Bridge(
                actionTransformation: { receivedInputAction in
                    receivedInputAction[keyPath: keyPathChecker].flatMap(outputAction)
                },
                statePredicate: stateAfterReducerPredicate,
                bridgedAtSource: ActionSource(file: file, function: function, line: line, info: nil)
            )
        )
        return self
    }

    private func on(
        _ keyPathChecker: KeyPath<InputActionType, Void?>,
        dispatch outputAction: OutputActionType,
        when stateAfterReducerPredicate: @escaping (GetState<StateType>) -> Bool = { _ in true },
        file: String = #file,
        line: UInt = #line,
        function: String = #function
    ) -> BridgeMiddleware {
        bridges.append(
            Bridge(
                actionTransformation: { receivedInputAction in
                    receivedInputAction[keyPath: keyPathChecker].map { _ in outputAction }
                },
                statePredicate: stateAfterReducerPredicate,
                bridgedAtSource: ActionSource(file: file, function: function, line: line, info: nil)
            )
        )
        return self
    }

    private var getState: GetState<StateType>?
    private var output: AnyActionHandler<OutputActionType>?

    public func receiveContext(getState: @escaping GetState<StateType>, output: AnyActionHandler<OutputActionType>) {
        self.getState = getState
        self.output = output
    }

    public func handle(action: InputActionType, from dispatcher: ActionSource, afterReducer: inout AfterReducer) {
        afterReducer = .do { [weak self] in
            guard let self = self,
                  let output = self.output,
                  let getState = self.getState
            else { return }

            self.bridges
                .filter { actionBridge in actionBridge.statePredicate(getState) }
                .compactMap { actionBridge in
                    actionBridge
                        .actionTransformation(action)
                        .map { derivedAction in (derivedAction, actionBridge.bridgedAtSource) }
                }
                .forEach { derivedAction, bridgedAtSource in
                    output.dispatch(
                        derivedAction,
                        from: ActionSource(
                            file: dispatcher.file,
                            function: dispatcher.function,
                            line: dispatcher.line,
                            info: [
                                dispatcher.info,
                                "Bridged from \(action) at \(bridgedAtSource.file), \(bridgedAtSource.function):\(bridgedAtSource.line)"
                            ]
                            .compactMap { $0 }
                            .joined(separator: "\n")
                        )
                    )
                }
        }
    }
}
