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
- A separate `SubscriptionRevenueCatUI` product that shows a paywall built with RevenueCat
  Paywalls, and switches between it and the app's own from one place
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

- A free trial appears as a caption under the plan, and only for a customer the store will give
  it to (`SubscriptionPackage.introductoryOffer`; `IntroductoryOffer` carries the length, the
  eligibility and the date the regular price is first charged).
- Pass `offering:` to sell an offering by identifier instead of the current one
  (`SubscriptionUseCase.loadOffering(id:)`, `purchase(packageId:inOffering:)`).
- `onPending` is called for a purchase waiting for approval (Ask to Buy), `onNothingToRestore`
  for a restore that finds nothing.
- `labels: .japanese` for the Japanese wording.
- A widget, or any process without a use case, reads the same `EntitlementCache` and applies
  `CachedEntitlement.lastKnownStatus(gracePeriod:at:)` to reach the app's answer.

### Switching to a RevenueCat paywall

`SubscriptionRevenueCatUI` is the only product that links RevenueCatUI. It shows a paywall
designed in the RevenueCat dashboard, and `PaywallContainer` chooses between that and the app's
own paywall according to a `PaywallMode`:

| `PaywallMode` | What is shown |
|---|---|
| `.custom` | Always the app's own paywall. RevenueCat is not asked anything |
| `.revenueCat(offering:)` | The RevenueCat paywall for the offering (`nil` for the current one) |
| `.automatic(offering:)` | The RevenueCat paywall if the offering has one attached in the dashboard, the app's own otherwise |
| `.revenueCat(placement:)` / `.automatic(placement:)` | The same, for the offering the dashboard serves at a placement |

Whatever stops a RevenueCat paywall from being shown — no `SubscriptionUseCase` in the
environment, the SDK not configured, the offerings failing to load, an offering that is not
there — ends at the app's own paywall.

```swift
import SubscriptionRevenueCatUI
import SubscriptionUI

PaywallContainer(
    mode: .automatic,
    onEntitled: { analytics.track(.purchaseCompleted) }
) { handlers in
    NavigationStack {
        PaywallView(
            pages: pages,
            links: links,
            offering: handlers.offeringIdentifier,
            onEntitled: handlers.onEntitled,
            onError: handlers.onError,
            onPending: handlers.onPending,
            onNothingToRestore: handlers.onNothingToRestore
        )
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", action: handlers.onDismiss)
            }
        }
    }
}
```

The container adds no chrome to either paywall. The RevenueCat paywall draws its own close
button, so the navigation bar and the close button go inside the `custom` closure, and the
container is presented bare. `onEntitled`, `onError`, `onDismiss`, `onPending` and
`onNothingToRestore` are called for both paywalls; the app's own gets them as the
`PaywallHandlers` passed to the closure. Pass `handlers.offeringIdentifier` on to `PaywallView`
so that the fallback sells the offering the mode named.

`PaywallMode` and the rule that turns it into a choice (`PaywallMode.choice(for:)`) live in
`SubscriptionUI`, so an app can hold the setting without linking RevenueCatUI.

#### Custom variables and what was bought

A dashboard paywall shows app values where its text says `{{ custom.name }}`. Pass them as
`PaywallVariable`s, and take the `SubscriptionStatus` the purchase left behind:

```swift
PaywallContainer(
    mode: .automatic,
    variables: ["headline": .string(headline), "trial_charge_date": .string("9/17")],
    onEntitled: { status in
        if status.activePackageId == "pro.yearly" { askForNotifications() }
    }
) { handlers in … }
```

`status.activePackageId` is the App Store product identifier. `SubscriptionPackage.productId`
is the same identifier on the paywall's side, whatever the package is called in the dashboard.
`.paywallVariables(_:)` sets the variables from any ancestor of a `RevenueCatPaywallView`.

## Documentation

**[API documentation and Getting Started](https://no-problem-dev.github.io/swift-subscription/documentation/subscription/)**

The Getting Started guide covers the App Store Connect and RevenueCat dashboard setup that
has to be in place first, choosing where the entitlement is kept, building a paywall, and what
cannot be tested on a simulator.

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.0+
- [RevenueCat SDK](https://github.com/RevenueCat/purchases-ios) 5.90.0+

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-subscription.git", from: "3.0.0")
]
```

Or in Xcode, `File > Add Package Dependencies...` with
`https://github.com/no-problem-dev/swift-subscription`.

## License

[MIT](./LICENSE)
