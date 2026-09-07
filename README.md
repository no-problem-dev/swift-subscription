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

- Entitlements that survive a launch, so a cold start with no network does not turn a paying
  customer into a free one
- Local and authoritative entitlement reads, kept deliberately separate, and told apart in the
  value itself rather than by convention
- Purchase, restore, and sign-in flows
- An `AsyncStream` of entitlement changes, including ones the app did not cause
- A separate `SubscriptionUI` product with a paywall skeleton that keeps the billed amount the
  most prominent price on screen
- Sendable throughout, with an actor holding the state

## Usage

```swift
import Subscription

let useCase = SubscriptionUseCaseImpl(
    configuration: SubscriptionConfiguration(apiKey: apiKey, entitlementId: "premium"),
    entitlementCache: FileEntitlementCache(url: entitlementFileURL)
)

if try await useCase.checkSubscriptionStatus().isActive {
    unlockPremium()
}
```

`checkSubscriptionStatus()` asks the store and is the read to trust when it decides whether
someone keeps access. `getSubscriptionStatus()` is the instant counterpart, answering from what
the device already knows.

That knowledge outlives the process. Every reading the store confirms is written to the
`EntitlementCache` you supply, and a launch that cannot reach the store starts from it rather
than from "not subscribed" — honoured for `gracePeriod` past the expiration date, and reported
as `.lastKnown(at:)` so the caller can tell it apart from an answer the store just gave.

```swift
switch status.verification {
case .confirmed:            break   // The store answered in this launch.
case .lastKnown(let date):  break   // Running on what it said at `date`.
case .unverified:           break   // Nothing known yet — not the same as not subscribed.
}
```

There is no default cache, because the place belongs to the app: a file, an app group's
`UserDefaults`, or the keychain. `InMemoryEntitlementCache` opts out, at the cost the first
bullet describes.

## Paywall

`SubscriptionUI` is a separate product carrying the parts of a paywall that are the same in
every app. It depends on no design system and chooses no colour, typeface or background.

```swift
import SubscriptionUI

PaywallView(
    pages: [PaywallPage(id: "unlock") { UnlockArtwork() }],
    links: PaywallLegalLinks(terms: termsURL, privacy: privacyURL),
    onEntitled: { dismiss() }
)
```

It loads the current offering, puts the annual plan first and preselects it, pages through
whatever pages you give it, and carries the restore button and the two legal links. The price
that will be billed is the largest text in every plan row and there is no parameter that can
change that, which is App Store Review 3.1.2(c) enforced by construction rather than by
documentation.

## Documentation

**[API documentation and Getting Started](https://no-problem-dev.github.io/swift-subscription/documentation/subscription/)**

The Getting Started guide covers the App Store Connect and RevenueCat dashboard setup that
has to be in place first, choosing where the entitlement is kept, building a paywall, and what
cannot be tested on a simulator.

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.0+
- [RevenueCat SDK](https://github.com/RevenueCat/purchases-ios) 5.14.0+

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-subscription.git", from: "2.0.0")
]
```

Or in Xcode, `File > Add Package Dependencies...` with
`https://github.com/no-problem-dev/swift-subscription`.

## License

[MIT](./LICENSE)
