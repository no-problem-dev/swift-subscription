/// Who sends `paywall_shown` for the paywall at the end of onboarding, and when.
///
/// The shared event catalog counts `paywall_shown` as an impression: the paywall was drawn and
/// seen, not merely put in the view tree.
public enum OnboardingPaywallImpression: Sendable, Hashable {
    /// The step sends ``OnboardingPaywallEvent/shown(paywallId:)`` once the paywall has been on
    /// screen for a second with the app in the foreground. Closed sooner, it sends none.
    case afterDwell

    /// The step sends no `paywall_shown`. The app sends it itself, with its own impression
    /// tracking (such as `trackImpression` or `trackScreen` in swift-analytics) and
    /// ``OnboardingPaywallContext/paywallId`` as `pw_id`.
    case byApp
}

/// The accessibility identifiers of the buttons ``OnboardingPaywallStep`` draws, for UI tests.
///
/// Fixed in every app and every language, so a test finds them without reading the labels.
public enum OnboardingPaywallIdentifier {
    /// The × in the top-leading corner.
    public static let close = "onboarding_paywall.close"

    /// "Continue for free" beneath the paywall.
    public static let continueFree = "onboarding_paywall.continue_free"

    /// "Restore Purchases" at the trailing end of the ×'s row.
    public static let restore = "onboarding_paywall.restore"
}
