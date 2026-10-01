# Changelog

All notable changes to this project are recorded in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Custom variables for paywalls built in the RevenueCat dashboard. `PaywallVariable`
  (`.string`, `.number`, `.bool`) lives in `SubscriptionUI`, so an app can build the values
  without linking RevenueCatUI. `PaywallContainer(mode:variables:onEntitled:…)` hands them to the
  RevenueCat paywall, and `.paywallVariables(_:)` does the same from any ancestor of a
  `RevenueCatPaywallView`. The app's own paywall does not read them.
- Placements. `PaywallMode.revenueCat(placement:)` and `.automatic(placement:)` look up the
  offering the dashboard serves at a placement (`Offerings.currentOffering(forPlacement:)`), and
  `PaywallMode.placementIdentifier` names it. A placement the dashboard does not know falls back
  to the current offering; a placement set to serve nothing ends at the app's own paywall.
- What was bought. The `onEntitled` of `PaywallContainer(mode:variables:…)` receives the
  `SubscriptionStatus` the purchase or restore left behind; `activePackageId` is the App Store
  product identifier. The existing initialiser and its argument-less `onEntitled` are unchanged.
- `SubscriptionPackage.productId`, the App Store product identifier, and an initialiser that
  takes it. The existing initialiser sets it to `id`.

### Fixed
- A package with a custom identifier in the dashboard (`pro.yearly` rather than `$rc_annual`)
  has the package type `.custom`, and its `duration` used to be `.unknown` and its
  `pricePerMonth` `nil`. Both are now read from the product's subscription period: one year or
  twelve months is `.annual`, one month is `.monthly`.

### Changed
- The minimum RevenueCat SDK is 5.90.0 (was 5.19.0): dashboard paywalls with display rules and
  `offer_price_with_zero` need it. An app pinned below 5.90.0 stops resolving until it raises
  its own requirement.
- `PaywallMode` holds a placement. Two modes that differ only in placement are no longer equal,
  so `PaywallContainer` decides again when the placement changes.

### Compatibility
- Source compatible with 3.0.0: no public symbol was removed or changed, and every addition is a
  new overload or a new property. Code that constructs `SubscriptionPackage` with the existing
  initialiser keeps compiling and gets `productId == id`.
- Behaviour change to check: an app that skipped `.unknown` packages, and whose dashboard uses
  custom package identifiers, now receives those packages as `.annual` / `.monthly`.

## [3.0.0] - 2026-09-30

### Added
- Introductory offers. `SubscriptionPackage.introductoryOffer` is an `IntroductoryOffer`: how it
  is paid (`.freeTrial`, `.payAsYouGo`, `.payUpFront`), one period and how many, the price, and
  whether this customer can take it (`.eligible`, `.ineligible`, `.unknown`). The eligibility is
  asked of the store when the offering loads, and only for packages that have an offer.
  `isEligibleFreeTrial` is the one question a paywall asks before writing "7 days free", and
  `regularBillingDate(from:in:)` is the date the regular price is first charged, counted in
  calendar units. Anything the store did not answer "eligible" is not eligible, so a customer
  who has used the trial is never promised it.
- `PaywallPlanRow` shows a free trial as a caption under the plan title, from the new
  `PaywallLabels.freeTrial`, only when the customer is eligible. The price stays the largest text.
- Choosing an offering by identifier. `SubscriptionUseCase.loadOffering(id:)` and
  `purchase(packageId:inOffering:)`; `PaywallView(offering:)` loads and sells from that offering.
  An identifier the dashboard does not have finds nothing — the current offering is never sold in
  its place. Both calls have default implementations that answer from `loadOfferings()` and
  `purchase(packageId:)`, correct for a conformance that knows a single offering, so existing
  stand-ins compile unchanged.
- `PaywallHandlers.offeringIdentifier`, set by `PaywallContainer` from its mode. Passing it to
  `PaywallView` keeps the fallback to the app's own paywall selling the offering the mode named.
  Until now the fallback always sold the current offering.
- `SubscriptionError.purchasePending`: a purchase waiting for approval (Ask to Buy). Until now it
  arrived as `.purchaseFailed`.
- `onPending` and `onNothingToRestore` on `PaywallView`, `RevenueCatPaywallView`,
  `PaywallContainer` and `PaywallHandlers`. With no `onPending`, a pending purchase goes to
  `onError` as `.purchasePending`, so it is never silent. A restore that finds nothing still does
  not call `onEntitled`.
- `CachedEntitlement.lastKnownStatus(gracePeriod:at:)` is public, so a widget or another
  extension reading the app's `EntitlementCache` applies the same grace rule as the app.
- `PaywallLabels.japanese`, and `PaywallLabels.englishFreeTrial` / `japaneseFreeTrial` for apps
  that assemble their own labels.

### Changed
- **BREAKING.** `SubscriptionError` has a new case, `.purchasePending`. A `switch` over it with no
  `default` stops compiling. `catch` patterns are unaffected.
- **BREAKING.** New parameters, all defaulted, on `SubscriptionPackage.init`, `PaywallLabels.init`,
  `PaywallHandlers.init`, both `PaywallView` initialisers, `RevenueCatPaywallView.init` and
  `PaywallContainer.init`. Call sites keep compiling; the signatures changed.

### Migrating from 2.x
- Raise the requirement to `from: "3.0.0"`. No call site needs to change unless it switches over
  `SubscriptionError` exhaustively; add `.purchasePending` there, as an outcome, not an error.
- A pending purchase used to reach `onError` as `.purchaseFailed`; it now reaches `onPending`, or
  `onError` as `.purchasePending` when there is none.
- To sell the offering a `PaywallContainer` mode names from the app's own paywall too, pass
  `offering: handlers.offeringIdentifier` to `PaywallView`.

## [2.1.0] - 2026-09-27

### Added
- A `SubscriptionRevenueCatUI` product, the only one that links RevenueCatUI. It carries
  `RevenueCatPaywallView`, which shows a paywall designed with RevenueCat Paywalls for an
  offering (the current one for `nil`), and `PaywallContainer`, which shows either that or the
  app's own paywall from one place. After a purchase or a restore the RevenueCat paywall asks the
  `SubscriptionUseCase` whether the customer is entitled, rather than reading the `CustomerInfo`
  RevenueCatUI hands back, so the configured entitlement decides and the `EntitlementCache` is
  refreshed; a restore that finds nothing does not count as entitled.
- `PaywallMode` in `SubscriptionUI`: `.custom`, `.revenueCat(offering:)` and
  `.automatic(offering:)`, with `.revenueCat` and `.automatic` as shorthands for the current
  offering. A struct rather than an enum, because an enum case with an associated value and a
  static property of the same name make `PaywallMode.automatic` ambiguous. `PaywallMode.choice(for:)` is the pure rule that turns the mode and a
  `PaywallOfferingLookup` into a `PaywallChoice`; everything that stops a RevenueCat paywall from
  being shown falls back to the app's own. Held in `SubscriptionUI` so that an app can keep the
  setting without linking RevenueCatUI.
- `PaywallHandlers`: the `onEntitled` / `onError` / `onDismiss` that `PaywallContainer` passes
  to the closure building the app's own paywall, so both paywalls report in the same three
  callbacks.

### Changed
- The minimum RevenueCat SDK is now 5.19.0, the first with `Offering.hasPaywall`.

## [2.0.0] - 2026-09-08

### Added
- The entitlement now survives a launch. `EntitlementCache` is a place the app supplies, every
  reading the store confirms is written to it, and a launch that cannot reach the store starts
  from what is there instead of from "not subscribed". `FileEntitlementCache`,
  `UserDefaultsEntitlementCache` and `InMemoryEntitlementCache` ship with it; there is no
  default, because the place belongs to the app. `UserDefaults.standard` is deliberately not
  one of the answers — an extension reads a different suite, and parallel tests write over each
  other's records.
- `SubscriptionConfiguration.gracePeriod`, three days by default: how long a cached entitlement
  is honoured past its expiration date while the store is unreachable. It is never applied to a
  reading the store answered, because the store runs a billing-retry grace of its own during
  which it reports an active entitlement whose date has already passed.
- `SubscriptionStatus.verification`, an `EntitlementVerification` of `.confirmed(at:)`,
  `.lastKnown(at:)` or `.unverified`. Replaying a cached entitlement is a rule, not a silent
  fallback, so the caller can see which of the three it is holding — and can tell "not
  subscribed" from "not known yet", which `.inactive` alone never distinguished.
- A `SubscriptionUI` product: `PaywallView` and the parts it is built from
  (`PaywallPage`, `PaywallPlanPicker`, `PaywallPlanRow`, `PaywallLegalFooter`,
  `PaywallLegalLinks`, `PaywallLabels`), plus `PreviewSubscriptionUseCase`. It depends on
  SwiftUI and `Subscription` only — no design system, and no colour, typeface or background
  choices. The billed amount is the largest text in every plan row and no parameter can change
  that, `PaywallLegalLinks` requires both the terms and the privacy URL, and several pages are
  paged through with an index. Until now the only `PaywallView` in this repository was a snippet
  inside the DocC article.

### Changed
- **Breaking.** `SubscriptionUseCaseImpl.init(configuration:)` now also takes
  `entitlementCache:`, with no default. Defaulting it to `UserDefaults.standard` would put the
  record where an extension cannot read it; defaulting it to the in-memory cache would keep the
  old behaviour under a new name. Both hide the choice, so the choice is required.
- **Breaking.** `SubscriptionStatus.init` and `SubscriptionConfiguration.init` take new
  parameters. Both have defaults, so call sites keep compiling, but the signatures changed.
- `getSubscriptionStatus()` answers from the cache before the store has replied, so `.inactive`
  early in a launch no longer means "nothing is known" by itself — read `verification` for that.
- `observeSubscriptionStatus()` stamps the statuses it yields, so a value taken from the stream
  carries the same provenance as one returned by `checkSubscriptionStatus()`.
- `syncUser(userId:)` drops the cached record along with the in-memory status when the identity
  differs from the one on record, and drops nothing when it is the same. The second half is what
  lets a relaunch out of signal keep the entitlement this device already confirmed.
- `clearUser()` clears the cache as well, so a signed-out account's entitlement does not come
  back on the next launch.
- DocC is built and hosted for both targets.

### Fixed
- A cold launch with no network reported every paying customer as unsubscribed. The entitlement
  lived only in an in-memory actor whose initial value was `.inactive`, and
  `checkSubscriptionStatus()` threw before it could write anything, so nothing ever replaced it.
  Where this did not happen, the RevenueCat SDK's own disk cache was answering — not a guarantee
  this package made.
- The test gate is back in CI. `.github/workflows/tests.yml` was removed on 2026-08-11, after
  1.0.5 had been tagged, which left that release's "Workflows synced to the shared template
  (tests, release-on-tag)" line describing something the repository no longer had. Every push
  and pull request now resolves dependencies fresh and runs `swift build` and `swift test`.

## [1.0.5] - 2026-07-19

### Added
- Tests for the entitlement decision, the annual-to-monthly price conversion, and the status
  cache, with an internal initializer as the injection seam.
- A DocC article covering getting started.
- A LICENSE file.

### Fixed
- The subscription observation task was never cancelled; it is now cancelled in `deinit`.

### Changed
- Doc comments and DocC rewritten in Japanese; README split into English and Japanese editions.
- Workflows synced to the shared template (tests, release-on-tag), replacing the previous
  auto-release workflow.
- DocC builds pinned to macOS 26 / Xcode 26 (Swift 6.2).

## [1.0.4] - 2025-11-09

### Fixed
- Automated release workflow messages (PR description, release notes, log output) made
  consistently Japanese.

## [1.0.3] - 2025-11-04

### Added
- DocC documentation generated and published to GitHub Pages: the Swift DocC plugin was added
  as a dependency, a GitHub Actions workflow builds and deploys the documentation, and the
  README links to it.

### Changed
- Documentation made easier to reach.

## [1.0.2] - 2025-02-11

### Changed
- README expanded with badges (Swift 6.0, platforms, SPM, licence), a quick start with
  complete code examples, real usage examples, error handling, and an explanation per example.

## [1.0.1] - 2025-02-11

### Added
- A separate LICENSE file carrying the MIT licence text.

### Changed
- The full licence text was removed from the README in favour of a reference to LICENSE.

## [1.0.0] - 2024-12-XX

### Added
- Initial release.
- RevenueCat integration.
- Checking and observing subscription status.
- Fetching available plans.
- Purchasing and restoring plans.
- Integration with user authentication.
- SwiftUI support (async/await, AsyncStream).
- Actor-based thread-safe design.
- iOS 17.0+ and macOS 14.0+ support.

[Unreleased]: https://github.com/no-problem-dev/swift-subscription/compare/1.0.5...HEAD
[1.0.5]: https://github.com/no-problem-dev/swift-subscription/compare/v1.0.4...1.0.5
[1.0.4]: https://github.com/no-problem-dev/swift-subscription/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/no-problem-dev/swift-subscription/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/no-problem-dev/swift-subscription/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/no-problem-dev/swift-subscription/compare/1.0.0...v1.0.1
