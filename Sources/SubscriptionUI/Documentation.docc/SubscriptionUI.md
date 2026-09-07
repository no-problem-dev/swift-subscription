# ``SubscriptionUI``

The parts of a paywall that are the same in every app, with the parts that are not left to you.

## Overview

`SubscriptionUI` draws a paywall's structure: the pages you supply on top, and beneath them the
plans, the purchase button, the restore button and the legal links. It depends on SwiftUI and
on `Subscription`, on no design system and on no third-party SDK, and it chooses no colour, no
typeface and no background. The look is yours.

It exists because the alternative is every app writing this again, and one of them getting the
prices the wrong way round.

```swift
import SubscriptionUI

PaywallView(
    pages: [
        PaywallPage(id: "unlock") { UnlockArtwork() },
        PaywallPage(id: "sync") { SyncArtwork() }
    ],
    links: PaywallLegalLinks(terms: termsURL, privacy: privacyURL),
    onEntitled: { dismiss() },
    onError: { presentedError = $0 }
)
```

That form reads the `SubscriptionUseCase` out of the environment, loads the current offering,
puts the annual plan first, preselects it, and buys and restores through it. Inject the use case
once at the root with `View.subscriptionUseCase(_:)`; without it the paywall renders a
configuration error rather than an empty screen, so a missed injection is visible during
development instead of at the till.

### The billed amount is the biggest number

App Store Review 3.1.2(c) rejects a paywall whose most prominent price is not the one that will
be charged — an annual plan headlined "¥500/month" with "¥6,000/year" underneath in grey being
the standard version. ``PaywallPlanRow`` makes that arrangement unavailable rather than
discouraged:

- the only text it renders large is `SubscriptionPackage.price`, the billed amount as the
  store formatted it
- `SubscriptionPackage.pricePerMonth` appears at caption size, in secondary colour, with
  ``PaywallLabels/perMonthSuffix`` attached — and the store supplies it only for annual packages
- there is no font, size, or alternative-headline parameter anywhere in the row
- ``PaywallLabels`` holds no price and cannot: every amount on the paywall comes from a
  `SubscriptionPackage`, and the purchase button takes a verb

An app that wants a different arrangement writes its own row, which makes it a decision rather
than an inherited rejection.

### Restore and the legal links are not optional

``PaywallLegalLinks`` requires both URLs, so there is no way to construct a paywall without
them, and ``PaywallLegalFooter`` carries the restore button beside them. Apple's standard EULA
is a valid answer for the terms when the app has none of its own.

### More than one page

Pass several ``PaywallPage`` values and ``PaywallView`` pages through them with an index. One
page gets no index. A paywall that carries its argument across several pages converts better
than one that crams it into a single screen, which is the reason paging is here rather than a
scroll view.

### Owning the purchase flow

``PaywallView/init(pages:packages:links:labels:purchase:restore:onError:)`` takes the plans and
the two actions directly and never touches the environment — for an app whose purchases go
through something of its own. ``PaywallPlanPicker``, ``PaywallPlanRow`` and
``PaywallLegalFooter`` are public for the same reason: an app that draws its own paywall can
still take the parts that are not design decisions.

## Topics

### The paywall

- ``PaywallView``
- ``PaywallPage``

### Its parts

- ``PaywallPlanPicker``
- ``PaywallPlanRow``
- ``PaywallLegalFooter``

### Configuration

- ``PaywallLegalLinks``
- ``PaywallLabels``

### Previews

- ``PreviewSubscriptionUseCase``
