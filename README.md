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

`SubscriptionCore` holds the values and the port (`SubscriptionUseCase`, `SubscriptionOffering`,
`SubscriptionPackage`, `SubscriptionStatus`, `SubscriptionError`) with no RevenueCat, so a
presentation layer and its tests can use them without building the SDK. `Subscription` adds
`SubscriptionUseCaseImpl`, the RevenueCat implementation, for the composition root, and
re-exports `SubscriptionCore`.

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

### Counting impressions of your own paywall

RevenueCat counts impressions of its own paywalls; one the app draws is invisible to the Paywall
Encounter chart until the app says it was shown. Call
`trackPaywallImpression(source:)` once per presentation, when the paywall is on screen, with
where it was shown from — `source` becomes RevenueCat's paywall identifier, so the chart splits by
it. A paywall that sells a named offering passes `offeringId:` as well, and one built from an
offering the package loaded passes the offering itself (`trackPaywallImpression(source:offering:)`),
so the impression carries the placement it was served at:

```swift
Task { await subscriptionUseCase.trackPaywallImpression(source: "settings") }
```

Each call is a separate impression, so guard it against a second `onAppear` for the same
presentation. RevenueCat paywalls (`RevenueCatPaywallView`) are counted by the SDK and need no call.

### Selling a different offering at each entry point

Name the place a paywall opens as a placement in the RevenueCat dashboard, and load what the
dashboard serves there. A placement the dashboard serves nothing at answers with the current
offering, so the app can ship before the dashboard is set up:

```swift
guard let offering = try await subscriptionUseCase.loadOffering(placement: "onboarding") else { return }
offering.servedBy            // .placement("onboarding"), or .current when nothing is served there
offering.metadata["appeal"]  // the dashboard's metadata, string values only
try await subscriptionUseCase.purchase(packageId: offering.packages[0].id, from: offering)
await subscriptionUseCase.trackPaywallImpression(source: "onboarding", offering: offering)
```

Buying and recording an impression with the offering itself, rather than its identifier, carries
the placement to RevenueCat. `metadata` keeps only string values; the keys of numbers, booleans and
objects are in `droppedMetadataKeys`, so a dashboard entry the app cannot read can be reported
rather than silently ignored.

### Ending onboarding on a paywall

Every app ends its onboarding on a paywall the customer can close. Decide once, before onboarding
starts, whether it appears; `OnboardingPaywallDecision` skips it for someone already entitled, when
the offering's metadata sets `onboarding_paywall` to `off`, and when there is no price to show:

```swift
let offering = try? await subscriptionUseCase.loadOffering(placement: OnboardingPaywallDecision.placement)
let status = await subscriptionUseCase.getSubscriptionStatus()
let decision = OnboardingPaywallDecision.decide(offering: offering, status: status)
// .show, or .skip(.entitled / .switchedOff / .nothingToSell)
```

Any value other than `off`, or no entry, leaves the paywall on, so a typo in the dashboard cannot
take it away. When it is shown, wrap the app's own paywall in `OnboardingPaywallStep`. It is in
the `SubscriptionOnboarding` product, which depends on SwiftUI only and not on RevenueCat, so a
presentation layer that does not import RevenueCat can draw and test it; `SubscriptionUI`
re-exports it. The step draws the × in the top-leading corner, "Restore Purchases" at the trailing
end of the same row when given `restore`, and "Continue for free" beneath the paywall, always, and
ends closing, continuing, buying and restoring in one `onFinish`:

```swift
import SubscriptionOnboarding

OnboardingPaywallStep(
    labels: .japanese,                    // ×, 購入を復元, 無料のまま続ける
    impression: .byApp,                   // the app sends paywall_shown; .afterDwell (default) lets the step
    onClose: { close in analytics.send(close.name, close.parameters) },
    onFinish: { exit in router.showHome(askForNotifications: exit.isEntitled) },
    restore: { await premium.restore() }  // true when the customer is entitled now
) { context in
    MyPaywall(
        paywallId: context.paywallId,     // the pw_id for the paywall's own paywall_* events
        onSelect: context.select,         // the plan selected now (PackageDuration?)
        onWorking: context.setWorking,    // disables the ways out while a purchase is in flight
        onPurchased: context.purchased    // the length of the plan bought (PackageDuration)
    )
}
```

`onEvent` receives `paywall_shown` and `paywall_closed` with `source=onboarding` and one `pw_id`,
named as in the shared event catalog. `paywall_shown` is an impression: by default the step sends
it once the paywall has been on screen for a second, and with `impression: .byApp` it sends none,
so the app can count it with its own impression tracking and `context.paywallId`. On closing,
`paywall_closed` has `result`, `via` (`close_button`, `continue_free`, or `auto` after a purchase or
a restore) and `open_s`. Its `product` is the plan bought; `onClose` hands the same close with the
plan last passed to `context.select`, so a close without a purchase names the plan that was
selected. Send `paywall_closed` from `onClose` or from `onEvent`, not both. The package depends on
no analytics SDK.

When `restore` answers `false`, the step stays open: say on the paywall that nothing was found.
The step has no parameter for the position of the ×, of "Restore Purchases", or for leaving out
"Continue for free".

Their look is the app's. Give each its own `ButtonStyle` (or a primitive one such as
`.borderedProminent`); they stay where they are:

```swift
OnboardingPaywallStep(onFinish: { _ in }) { context in MyPaywall(context) }
    .onboardingPaywallCloseButtonStyle(CircleCloseStyle())   // label: xmark in a 44-pt square
    .onboardingPaywallRestoreButtonStyle(.plain)
    .onboardingPaywallContinueFreeButtonStyle(.borderedProminent)
```

Its buttons carry fixed accessibility identifiers for UI tests, in every language:

| Button | Identifier (`OnboardingPaywallIdentifier`) |
|---|---|
| × | `onboarding_paywall.close` |
| Restore Purchases | `onboarding_paywall.restore` |
| Continue for free | `onboarding_paywall.continue_free` |

## Documentation

The DocC catalogs under `Sources/*/*.docc/` hold the API documentation and the Getting Started guide. Open them in Xcode with Product › Build Documentation.

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
