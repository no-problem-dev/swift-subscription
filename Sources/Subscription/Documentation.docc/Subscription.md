# ``Subscription``

Subscriptions and in-app purchases through RevenueCat, behind a small async API.

## Overview

`Subscription` wraps the RevenueCat SDK so an app deals in one protocol,
``SubscriptionUseCase``, instead of the store's own types. It covers the four things a
paywall needs: read the entitlement, list the products, buy one, and keep the answer current
as renewals and expiries arrive.

The distinction worth learning first is which read to trust.
``SubscriptionUseCase/getSubscriptionStatus()`` returns a cached value and never leaves the
device, so it is instant but starts out `.inactive` and stays there until a refresh lands.
``SubscriptionUseCase/checkSubscriptionStatus()`` asks the store and is the answer to rely on
when it decides whether a customer keeps access.

```swift
let useCase = SubscriptionUseCaseImpl(
    configuration: SubscriptionConfiguration(apiKey: apiKey, entitlementId: "premium")
)

guard let offering = try await useCase.loadOfferings() else { return }

do {
    let status = try await useCase.purchase(packageId: offering.packages[0].id)
    unlockPremium(status.isActive)
} catch SubscriptionError.purchaseCancelled {
    // The customer closed the sheet. Not a failure.
}
```

Entitlements also change without the app asking — an overnight renewal, a lapse, a purchase
made on another device. ``SubscriptionUseCase/observeSubscriptionStatus()`` reports those.

### Testing against the store

Purchases cannot be exercised on a simulator started by `simctl`. A `.storekit`
configuration file is applied only by an Xcode IDE Run; a `simctl` launch ignores it and
falls through to the real App Store sandbox. Automated checks therefore cover the pure
decision logic, and the purchase and restore paths need a device or an Xcode Run with a
sandbox account.

## Topics

### Essentials

- <doc:GettingStarted>
- ``SubscriptionUseCase``
- ``SubscriptionUseCaseImpl``

### Configuration

- ``SubscriptionConfiguration``

### Reading entitlement state

- ``SubscriptionStatus``

### Presenting a paywall

- ``SubscriptionOffering``
- ``SubscriptionPackage``
- ``PackageDuration``

### SwiftUI integration

- ``SubscriptionUseCaseModifier``
- ``SubscriptionUseCaseKey``

### Errors

- ``SubscriptionError``
