# Changelog

All notable changes to this project are recorded in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
