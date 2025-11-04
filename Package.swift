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
        .library(
            name: "Subscription",
            targets: ["Subscription"]
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
                .product(name: "RevenueCat", package: "purchases-ios"),
                .product(name: "RevenueCatUI", package: "purchases-ios")
            ],
            path: "Sources/Subscription"
        ),
        .testTarget(
            name: "SubscriptionTests",
            dependencies: ["Subscription"],
            path: "Tests/SubscriptionTests"
        )
    ]
)
