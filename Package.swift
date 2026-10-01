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
        ),
        // Paywalls built in the RevenueCat dashboard, and the container that chooses between one
        // of those and the app's own. The only product that links RevenueCatUI, so an app that
        // draws its own paywall does not carry it.
        .library(
            name: "SubscriptionRevenueCatUI",
            targets: ["SubscriptionRevenueCatUI"]
        )
    ],
    dependencies: [
        // RevenueCat SDK
        .package(url: "https://github.com/RevenueCat/purchases-ios.git", from: "5.90.0"),
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
        .target(
            name: "SubscriptionRevenueCatUI",
            dependencies: [
                "Subscription",
                "SubscriptionUI",
                .product(name: "RevenueCat", package: "purchases-ios"),
                .product(name: "RevenueCatUI", package: "purchases-ios")
            ],
            path: "Sources/SubscriptionRevenueCatUI"
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
        ),
        .testTarget(
            name: "SubscriptionRevenueCatUITests",
            dependencies: [
                "SubscriptionRevenueCatUI",
                .product(name: "RevenueCat", package: "purchases-ios"),
                .product(name: "RevenueCatUI", package: "purchases-ios")
            ],
            path: "Tests/SubscriptionRevenueCatUITests"
        )
    ]
)
