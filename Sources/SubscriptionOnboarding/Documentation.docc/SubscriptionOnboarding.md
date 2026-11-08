# ``SubscriptionOnboarding``

The paywall at the end of onboarding, with the ways out every app must have.

## Overview

Every app ends its onboarding on a paywall the customer can close. Whether it appears is
`OnboardingPaywallDecision`'s call, in `Subscription`. When it does, ``OnboardingPaywallStep``
wraps the app's own paywall in the parts that must not differ between apps: a × in the top-leading
corner from the first frame, "Restore Purchases" at the trailing end of the same row, "Continue for
free" beneath the paywall, one `onFinish` for closing, continuing, buying and restoring alike, and
`source=onboarding` on the `paywall_shown` and `paywall_closed` it reports.

This module depends on SwiftUI only. It has no RevenueCat, so a presentation layer that does not
import RevenueCat can draw it and test it: the paywall reports plans by their length
(`PackageDuration`), not by a RevenueCat package. `SubscriptionUI` re-exports it.

## Topics

### The step

- ``OnboardingPaywallStep``
- ``OnboardingPaywallContext``
- ``OnboardingPaywallExit``
- ``OnboardingPaywallLabels``
- ``OnboardingPaywallIdentifier``

### Analytics

- ``OnboardingPaywallImpression``
- ``OnboardingPaywallEvent``
- ``OnboardingPaywallClose``
