# Subscription

Subscriptions and in-app purchases through RevenueCat, behind a small async API.

![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017.0%2B%20%7C%20macOS%2014.0%2B-blue.svg)
![SPM](https://img.shields.io/badge/SPM-compatible-green.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

English | [日本語](./README.ja.md)

## Overview

An app talks to one protocol, `SubscriptionUseCase`, instead of the store's own types. It
covers what a paywall needs: read the entitlement, list the products, buy one, and keep the
answer current as renewals and expiries arrive.

- Cached and authoritative entitlement reads, kept deliberately separate
- Purchase, restore, and sign-in flows
- An `AsyncStream` of entitlement changes, including ones the app did not cause
- Sendable throughout, with an actor holding the cached state

## Usage

```swift
import Subscription

let useCase = SubscriptionUseCaseImpl(
    configuration: SubscriptionConfiguration(apiKey: apiKey, entitlementId: "premium")
)

if try await useCase.checkSubscriptionStatus().isActive {
    unlockPremium()
}
```

`checkSubscriptionStatus()` asks the store and is the read to trust when it decides whether
someone keeps access. `getSubscriptionStatus()` is the instant, cached counterpart — it
starts out inactive, so early in a launch that answer means "not known yet".

## Documentation

**[API documentation and Getting Started](https://no-problem-dev.github.io/swift-subscription/documentation/subscription/)**

The Getting Started guide covers the App Store Connect and RevenueCat dashboard setup that
has to be in place first, building a paywall, and what cannot be tested on a simulator.

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.0+
- [RevenueCat SDK](https://github.com/RevenueCat/purchases-ios) 5.14.0+

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-subscription.git", from: "1.0.4")
]
```

Or in Xcode, `File > Add Package Dependencies...` with
`https://github.com/no-problem-dev/swift-subscription`.

## License

[MIT](./LICENSE)
