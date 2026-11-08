# Contributing

Thanks for taking the time to look at this package.

## Reporting a problem

Open an issue with the smallest example that reproduces it, the Swift and Xcode
versions you're on, and the platform you're targeting. A failing test is the
clearest possible report.

## Working on a change

```bash
swift build
swift test
```

There is no CI. Run both commands locally before merging. A `.build` left over
from an earlier resolve can report green where a fresh checkout does not, so after
changing a dependency pin run `swift build --build-tests` from a clean `.build`.

Snapshot tests are run separately: the recorded pixels follow
the host simulator's scale, so they are compared locally with
`xcodebuild test -destination 'platform=iOS Simulator,...'`. Wrap image-test files
in `#if canImport(UIKit)` so the macOS run leaves them out.

Documentation lives in the DocC catalog under `Sources/*/*.docc/`. Public
declarations are documented with `///` comments, in English.

## Releasing

Maintainers only. Rename `## [Unreleased]` in `CHANGELOG.md` to the new version,
merge to `main`, then tag and push:

```bash
git tag x.y.z && git push origin x.y.z
```

Versions follow SemVer: removing or changing a public symbol is a major, additions
are a minor. No GitHub Release is created.
