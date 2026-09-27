import Foundation

/// Which paywall an app wants to show: the one it draws itself, or one built in the RevenueCat
/// dashboard with RevenueCat Paywalls.
///
/// The mode is a wish, not the outcome. What is actually shown is decided by
/// ``choice(for:)`` once the offering has been looked up, and anything that goes wrong on the
/// RevenueCat side ends at the app's own paywall rather than at an empty sheet.
///
/// This type lives here, and not beside the RevenueCat paywall, so that an app can hold and
/// switch the setting without linking RevenueCatUI. Showing a RevenueCat paywall needs the
/// `SubscriptionRevenueCatUI` product.
public enum PaywallMode: Sendable, Hashable {
    /// Always the app's own paywall. RevenueCat is not asked anything.
    case custom

    /// The RevenueCat paywall for an offering, `nil` meaning the current one.
    ///
    /// Shown even when the offering has no paywall attached in the dashboard, in which case
    /// RevenueCatUI draws its default one from the offering's packages. Only an offering that
    /// cannot be found or loaded falls back to the app's own paywall.
    case revenueCat(offering: String?)

    /// The RevenueCat paywall when the offering has one attached in the dashboard, and the
    /// app's own paywall otherwise.
    ///
    /// The setting to ship with when the dashboard is where paywalls are designed but not every
    /// offering has one yet: attaching a paywall switches it on without an app release, and
    /// detaching it switches it off.
    case automatic(offering: String?)

    /// The RevenueCat paywall for the current offering.
    public static var revenueCat: PaywallMode { .revenueCat(offering: nil) }

    /// The RevenueCat paywall for the current offering if it has one, the app's own otherwise.
    public static var automatic: PaywallMode { .automatic(offering: nil) }

    /// The offering to look up, or `nil` for the current one.
    ///
    /// Also `nil` for ``custom``, which looks nothing up; ask ``needsLookup`` to tell the two
    /// apart.
    public var offeringIdentifier: String? {
        switch self {
        case .custom:
            return nil
        case .revenueCat(let offering), .automatic(let offering):
            return offering
        }
    }

    /// Whether ``choice(for:)`` depends on anything RevenueCat knows.
    ///
    /// `false` only for ``custom``, which shows the app's paywall straight away, without a
    /// loading state and without a network round trip.
    public var needsLookup: Bool {
        self != .custom
    }

    /// The paywall to show, given what the lookup of the offering found.
    ///
    /// | mode | ``PaywallOfferingLookup/hasPaywall`` | ``PaywallOfferingLookup/noPaywall`` | ``PaywallOfferingLookup/offeringMissing`` | ``PaywallOfferingLookup/unavailable`` |
    /// |---|---|---|---|---|
    /// | ``custom`` | custom | custom | custom | custom |
    /// | ``revenueCat(offering:)`` | RevenueCat | RevenueCat | custom | custom |
    /// | ``automatic(offering:)`` | RevenueCat | custom | custom | custom |
    ///
    /// - Parameter lookup: What looking up ``offeringIdentifier`` found.
    /// - Returns: The paywall to show.
    public func choice(for lookup: PaywallOfferingLookup) -> PaywallChoice {
        switch (self, lookup) {
        case (.custom, _):
            return .custom
        case (_, .offeringMissing), (_, .unavailable):
            return .custom
        case (.revenueCat, .hasPaywall), (.revenueCat, .noPaywall):
            return .revenueCat
        case (.automatic, .hasPaywall):
            return .revenueCat
        case (.automatic, .noPaywall):
            return .custom
        }
    }
}

/// What looking up an offering in RevenueCat found, as far as choosing a paywall is concerned.
public enum PaywallOfferingLookup: Sendable, Hashable {
    /// The offering exists and has a paywall attached in the dashboard.
    case hasPaywall

    /// The offering exists and has no paywall attached.
    case noPaywall

    /// The offerings loaded, but not the one asked for: an identifier that is not in the
    /// dashboard, or no offering marked current.
    case offeringMissing

    /// RevenueCat could not answer: the SDK is not configured, no `SubscriptionUseCase` is in
    /// the environment, or the offerings failed to load.
    case unavailable
}

/// The paywall that ``PaywallMode/choice(for:)`` settled on.
public enum PaywallChoice: Sendable, Hashable {
    /// The app's own paywall.
    case custom

    /// The paywall built with RevenueCat Paywalls.
    case revenueCat
}
