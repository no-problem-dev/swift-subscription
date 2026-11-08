// `PackageDuration` lives in `SubscriptionPlan`, a target of this package with no dependency, and
// is the type `OnboardingPaywallContext.select(_:)` and `purchased(_:)` take. `SubscriptionPlan` is
// not a product, so an app can import it only through a product: re-exported here as
// `Subscription` does, so `import SubscriptionOnboarding` is enough to name it.
@_exported import SubscriptionPlan
