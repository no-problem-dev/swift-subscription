# Getting Started

Take an app from no billing to a working paywall.

## Before you write any code

Subscriptions are configured in three places that must agree, and the most common cause of
"my paywall is empty" is that they do not.

1. **App Store Connect** — create the subscription products. Until they exist here, nothing
   downstream can see them.
2. **RevenueCat dashboard** — import those products, then define an *entitlement* (the
   conventional name is `premium`). The entitlement is what this package checks; the
   products are merely what grants it.
3. **An offering** — group the products a paywall should show and mark one offering as
   current. ``SubscriptionUseCase/loadOfferings()`` returns `nil` when none is marked, which
   is a dashboard problem rather than a failure it can report as an error.

The entitlement identifier you choose has to be passed to
``SubscriptionConfiguration/init(apiKey:entitlementId:customAttributesSetter:)`` exactly. A
mismatch does not raise an error — it makes every paying customer look unsubscribed.

## Create the use case

Create one instance for the process. The RevenueCat SDK is configured globally, so a second
instance reconfigures it.

```swift
import Subscription

let subscriptionUseCase: SubscriptionUseCase = SubscriptionUseCaseImpl(
    configuration: SubscriptionConfiguration(
        apiKey: "appl_xxxxxxxxxxxxxxxxxxxxxxxxxx",
        entitlementId: "premium"
    )
)
```

Use the platform's *public* SDK key. It ships inside the app and is readable by anyone who
inspects the binary.

In a SwiftUI app, inject it once at the root:

```swift
@main
struct MyApp: App {
    private let subscriptionUseCase: SubscriptionUseCase = SubscriptionUseCaseImpl(
        configuration: SubscriptionConfiguration(apiKey: "appl_xxxxxx")
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
                .subscriptionUseCase(subscriptionUseCase)
        }
    }
}
```

Views resolve it from the environment, where it is optional because previews and any screen
outside the injection point get `nil`:

```swift
struct PaywallView: View {
    @Environment(\.subscriptionUseCase) private var subscriptionUseCase
}
```

## Gate a feature on the entitlement

Two reads exist and choosing the wrong one is the mistake that reaches customers.

```swift
// Instant, from cache. `.inactive` here can mean "not known yet".
let cached = await subscriptionUseCase.getSubscriptionStatus()

// Authoritative, over the network. Use this when it decides access.
let current = try await subscriptionUseCase.checkSubscriptionStatus()
```

At launch the cache is `.inactive` because nothing has filled it yet. Locking premium
features on that value alone shuts a paying subscriber out of what they bought for as long
as the first refresh takes. Render the optimistic state, or a neutral one, until a refresh
lands.

## Build the paywall

Present whatever the current offering contains rather than assuming a fixed monthly and
annual pair — which offering is current is a server-side decision that changes without an
app release.

```swift
let offering = try await subscriptionUseCase.loadOfferings()
for package in offering?.packages ?? [] {
    print(package.title, package.price)     // already localized and currency-formatted
}
```

`price` and `pricePerMonth` arrive formatted for the customer's storefront. Do not reformat
them or assume a currency symbol.

> Warning: ``PackageDuration`` raw values are hard-coded Japanese strings. Switch over the
> case and supply your own localized label instead of rendering `rawValue`.

## Purchase and restore

```swift
do {
    let status = try await subscriptionUseCase.purchase(packageId: package.id)
    unlockPremium(status.isActive)
} catch SubscriptionError.purchaseCancelled {
    // Expected: the customer dismissed the sheet. Do not show an alert.
} catch {
    showAlert(error.localizedDescription)
}
```

`packageId` is ``SubscriptionPackage/id`` from the offering, not an App Store product
identifier.

Restoring needs care, because succeeding is not the same as finding something:

```swift
let status = try await subscriptionUseCase.restorePurchases()
if status.isActive {
    unlockPremium(true)
} else {
    showMessage("No purchases were found for this Apple Account.")
}
```

Branching on the absence of a thrown error instead of on `isActive` tells a customer who
never subscribed that their purchases were restored.

## Keep it current

Renewals, expiries, and purchases made on another device all arrive here:

```swift
for await status in subscriptionUseCase.observeSubscriptionStatus() {
    await MainActor.run { isPremium = status.isActive }
}
```

## Tie purchases to your accounts

Until an identity is attached, purchases belong to an anonymous one and do not follow the
customer to another device.

```swift
try await subscriptionUseCase.syncUser(userId: user.id)   // after sign-in
try await subscriptionUseCase.clearUser()                 // after sign-out
```

Skipping the sign-out call leaves the previous account's entitlement readable by whoever
signs in next on that device.

## What you cannot test on a simulator

A `.storekit` configuration file is applied only by an Xcode IDE Run. A simulator launched
by `simctl` ignores it and falls through to the real App Store sandbox, so purchase and
restore flows cannot be driven by automation there. Verify those on a device, or from an
Xcode Run with a sandbox account.
