import Foundation
import SwiftRex

infix operator |>: ForwardApplication
precedencegroup ForwardApplication {
    associativity: left
    lowerThan: TernaryPrecedence
    higherThan: AssignmentPrecedence
}

infix operator >>>: ForwardComposition
infix operator >=>: ForwardComposition
precedencegroup ForwardComposition {
    associativity: left
    lowerThan: TernaryPrecedence
    higherThan: ForwardApplication
}

/// Terminal object composition. Makes a Void out of anything.
/// It's used in a composition to ignore whatever value is given.
public func ignore<A>(_ a: A) {
    return ()
}

/// Apply a value into a function. Given a function from A to B, applying A will result in B.
public func |> <A, B>(_ value: A, f: @escaping (A) -> B) -> B {
    f(value)
}

/// To compose two functions when the input of the second function matches the result of the first.
public func >>> <A, B, C>(f: @escaping (A) -> B, g: @escaping (B) -> C) -> (A) -> C {
    return { a in
        g(f(a))
    }
}

/// To compose two Optional results of functions, when the input of the second function matches the result of the first, but
/// only in case it's not nil. And also the result of the second is itself Optional as well, so the final function will flatMap both optionals.
/// Version where the first function is actually a KeyPath.
public func >=> <A, B, C>(_ left: KeyPath<A, B?>, _ right: @escaping (B) -> C?) -> ((A) -> C?) {
    { (a: A) -> C? in
        let maybeB = a[keyPath: left]
        let maybeC = maybeB.flatMap(right)
        return maybeC
    }
}

/// To compose two Optional results of functions, when the input of the second function matches the result of the first, but
/// only in case it's not nil. And also the result of the second is itself Optional as well, so the final function will flatMap both optionals.
/// Version where both functions are actually KeyPaths.
public func >=> <A, B, C>(_ left: KeyPath<A, B?>, _ right: KeyPath<B, C?>) -> ((A) -> C?) {
    { (a: A) -> C? in
        let maybeB = a[keyPath: left]
        let maybeC = maybeB.flatMap { b in b[keyPath: right] }
        return maybeC
    }
}

/// To compose two Optional results of functions, when the input of the second function matches the result of the first, but
/// only in case it's not nil. And also the result of the second is itself Optional as well, so the final function will flatMap both optionals.
/// Version where the second function is actually a KeyPath.
public func >=> <A, B, C>(_ left: @escaping (A) -> B?, _ right: KeyPath<B, C?>) -> ((A) -> C?) {
    { (a: A) -> C? in
        let maybeB = left(a)
        let maybeC = maybeB.flatMap { b in b[keyPath: right] }
        return maybeC
    }
}

/// To compose two Optional results of functions, when the input of the second function matches the result of the first, but
/// only in case it's not nil. And also the result of the second is itself Optional as well, so the final function will flatMap both optionals.
public func >=> <A, B, C>(_ left: @escaping (A) -> B?, _ right: @escaping (B) -> C?) -> ((A) -> C?) {
    { (a: A) -> C? in
        let maybeB = left(a)
        let maybeC = maybeB.flatMap(right)
        return maybeC
    }
}

public class BridgeMiddleware<InputActionType, OutputActionType, StateType>: MiddlewareProtocol {
    struct Bridge {
        let actionTransformation: (InputActionType, GetState<StateType>) -> OutputActionType?
        let statePredicate: (GetState<StateType>, InputActionType) -> Bool
        let bridgedAtSource: ActionSource
    }

    var bridges: [Bridge] = []

    public init() { }

    /// Bridge an action to another derived action
    ///
    /// - Parameters:
    ///   - mapping: an arrow from Input Action resolving and filtering incoming actions to filter for one in particular, to a
    ///              derived action, such as in `{ action in AppAction.another(.tree(.myDerivedAction)) }`.
    ///   - stateAfterReducerPredicate: optional filter in case the state (after reducer) is not the way you want, for example:
    ///                                 `{ getState in getState().qa.theStateOfSomething == .active }`
    ///   - file: file where the bridge happens, most of the times you want this to default to #file
    ///   - line: line where the bridge happens, most of the times you want this to default to #line
    ///   - function: function where the bridge happens, most of the times you want this to default to #function
    /// - Returns: The instance of this middleware itself, modified with the new bridge
    public func bridge(
        _ mapping: @escaping (InputActionType) -> OutputActionType?,
        when stateAfterReducerPredicate: @escaping (GetState<StateType>) -> Bool = { _ in true },
        file: String = #file,
        line: UInt = #line,
        function: String = #function
    ) -> BridgeMiddleware {
        bridges.append(
            Bridge(
                actionTransformation: { action, _ in mapping(action) },
                statePredicate: { state, _ in stateAfterReducerPredicate(state) },
                bridgedAtSource: ActionSource(file: file, function: function, line: line, info: nil)
            )
        )
        return self
    }

    /// Bridge an action to another derived action
    ///
    /// - Parameters:
    ///   - mapping: an arrow from Input Action and current State resolving and filtering incoming actions to filter for one in particular, to a
    ///              derived action, such as in `{ action, state in AppAction.another(.tree(.myDerivedAction)) }` If, after evaluating incoming
    ///              action and state you decide that you don't want to bridge to another action, simply return nil from the closure.
    ///   - file: file where the bridge happens, most of the times you want this to default to #file
    ///   - line: line where the bridge happens, most of the times you want this to default to #line
    ///   - function: function where the bridge happens, most of the times you want this to default to #function
    /// - Returns: The instance of this middleware itself, modified with the new bridge
    public func bridgeWithState(
        _ mapping: @escaping (InputActionType, GetState<StateType>) -> OutputActionType?,
        file: String = #file,
        line: UInt = #line,
        function: String = #function
    ) -> BridgeMiddleware {
        bridges.append(
            Bridge(
                actionTransformation: mapping,
                statePredicate: { _, _ in true },
                bridgedAtSource: ActionSource(file: file, function: function, line: line, info: nil)
            )
        )
        return self
    }

    /// Bridge an action to another derived action
    ///
    /// - Parameters:
    ///   - keyPathChecker: A key path resolving from the App Action to a possible tree where your action of interest should be. Because maybe
    ///                     the action is totally unrelated to what you expect, the keypath resolves to an Optional object or `Optional<Void>`,
    ///                     which is nil in case the action is in a different tree and you will not bridge.
    ///   - outputAction: action to be dispatched in case the original action matches your keyPathChecker. If there's an associated value to be
    ///                   transferred, it will be accessible from this closure, on which you can optionally return the derived action or nil in
    ///                   case you decide to not dispatch anything after checking the associated value, for example.
    ///   - stateAfterReducerPredicate: optional filter in case the state (after reducer) is not the way you want, for example:
    ///                                 `{ getState in getState().qa.theStateOfSomething == .active }`
    ///   - file: file where the bridge happens, most of the times you want this to default to #file
    ///   - line: line where the bridge happens, most of the times you want this to default to #line
    ///   - function: function where the bridge happens, most of the times you want this to default to #function
    /// - Returns: The instance of this middleware itself, modified with the new bridge
    public func bridge<Value>(
        on keyPathChecker: KeyPath<InputActionType, Value?>,
        dispatch outputAction: @escaping (Value) -> OutputActionType?,
        when stateAfterReducerPredicate: @escaping (GetState<StateType>) -> Bool = { _ in true },
        file: String = #file,
        line: UInt = #line,
        function: String = #function
    ) -> BridgeMiddleware {
        bridge(
            keyPathChecker >=> outputAction,
            when: stateAfterReducerPredicate,
            file: file,
            line: line,
            function: function
        )
    }

    /// Bridge an action to another derived action
    ///
    /// - Parameters:
    ///   - keyPathChecker: A key path resolving from the App Action to a possible tree where your action of interest should be. Because maybe
    ///                     the action is totally unrelated to what you expect, the keypath resolves to an `Optional<Void>`, which is nil in case
    ///                     the action is in a different tree and you will not bridge.
    ///   - outputAction: action to be dispatched in case the original action matches your keyPathChecker. It's an autoclosure, so you can give
    ///                   a hardcoded value or calculate one by opening the closure. In this version, there's no associated value to be transferred,
    ///                   if this is something you need, please check the other overload of this function.
    ///   - stateAfterReducerPredicate: optional filter in case the state (after reducer) is not the way you want, for example:
    ///                                 `{ getState in getState().qa.theStateOfSomething == .active }`
    ///   - file: file where the bridge happens, most of the times you want this to default to #file
    ///   - line: line where the bridge happens, most of the times you want this to default to #line
    ///   - function: function where the bridge happens, most of the times you want this to default to #function
    /// - Returns: The instance of this middleware itself, modified with the new bridge
    public func bridge(
        on keyPathChecker: KeyPath<InputActionType, Void?>,
        dispatch outputAction: @autoclosure @escaping () -> OutputActionType,
        when stateAfterReducerPredicate: @escaping (GetState<StateType>) -> Bool = { _ in true },
        file: String = #file,
        line: UInt = #line,
        function: String = #function
    ) -> BridgeMiddleware {
        bridge(keyPathChecker >=> (ignore >>> outputAction), when: stateAfterReducerPredicate, file: file, line: line, function: function)
    }

    public func handle(action: InputActionType, from dispatcher: ActionSource, state: @escaping GetState<StateType>) -> IO<OutputActionType> {
        IO { [weak self] output in
            guard let self = self else { return }

            self.bridges
                .filter { actionBridge in actionBridge.statePredicate(state, action) }
                .compactMap { actionBridge in
                    actionBridge
                        .actionTransformation(action, state)
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
