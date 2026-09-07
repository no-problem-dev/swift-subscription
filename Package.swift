// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Subscription",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // Entitlement state and the store calls that change it.
        .library(
            name: "Subscription",
            targets: ["Subscription"]
        ),
        // The paywall skeleton, SwiftUI and system frameworks only. A separate product so an
        // app that draws its own paywall does not carry it.
        .library(
            name: "SubscriptionUI",
            targets: ["SubscriptionUI"]
        )
    ],
    dependencies: [
        // RevenueCat SDK
        .package(url: "https://github.com/RevenueCat/purchases-ios.git", from: "5.14.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0")
    ],
    targets: [
        .target(
            name: "Subscription",
            dependencies: [
                .product(name: "RevenueCat", package: "purchases-ios")
            ],
            path: "Sources/Subscription"
        ),
        // No design system and no third-party dependency: the paywall's structure is what
        // this target owns, and the look belongs to the app.
        .target(
            name: "SubscriptionUI",
            dependencies: ["Subscription"],
            path: "Sources/SubscriptionUI"
        ),
        .testTarget(
            name: "SubscriptionTests",
            dependencies: ["Subscription"],
            path: "Tests/SubscriptionTests"
        ),
        .testTarget(
            name: "SubscriptionUITests",
            dependencies: ["SubscriptionUI"],
            path: "Tests/SubscriptionUITests"
        )
    ]
)
