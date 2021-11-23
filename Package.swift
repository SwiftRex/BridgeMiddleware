// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "BridgeMiddleware",
    products: [
        .library(name: "BridgeMiddlewareCombine", targets: ["BridgeMiddlewareCombine"]),
        .library(name: "BridgeMiddlewareRxSwift", targets: ["BridgeMiddlewareRxSwift"]),
        .library(name: "BridgeMiddlewareReactiveSwift", targets: ["BridgeMiddlewareReactiveSwift"])
    ],
    dependencies: [
        .package(url: "https://github.com/SwiftRex/SwiftRex.git", from: "0.8.8")
    ],
    targets: [
        .target(name: "BridgeMiddlewareCombine", dependencies: [.product(name: "CombineRex", package: "SwiftRex")]),
        .target(name: "BridgeMiddlewareRxSwift", dependencies: [.product(name: "RxSwiftRex", package: "SwiftRex")]),
        .target(name: "BridgeMiddlewareReactiveSwift", dependencies: [.product(name: "ReactiveSwiftRex", package: "SwiftRex")])
    ]
)
