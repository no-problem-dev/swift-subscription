# Changelog

All notable changes to this project are recorded in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
