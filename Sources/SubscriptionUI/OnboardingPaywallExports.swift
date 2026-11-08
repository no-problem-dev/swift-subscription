import SubscriptionCore
@_exported import SubscriptionOnboarding

// The onboarding step lives in `SubscriptionOnboarding`, which has no RevenueCat. Re-exported here
// so `import SubscriptionUI` still sees it, with the one call that takes a package.

extension OnboardingPaywallContext {
    /// Reports a purchase that left the customer entitled. Onboarding moves on.
    ///
    /// The same as `purchased(_:)` with the package's `duration`, for a paywall that holds the package.
    ///
    /// - Parameter package: The plan that was bought.
    @MainActor
    public func purchased(_ package: SubscriptionPackage) {
        purchased(package.duration)
    }
}
