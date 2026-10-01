import Foundation

/// Which paywall an app wants to show: the one it draws itself, or one built in the RevenueCat
/// dashboard with RevenueCat Paywalls.
///
/// The mode is a wish, not the outcome. What is actually shown is decided by
/// ``choice(for:)`` once the offering has been looked up, and anything that goes wrong on the
/// RevenueCat side ends at the app's own paywall rather than at an empty sheet.
///
/// A struct rather than an enum so that `PaywallMode.automatic` and `.revenueCat` can name the
/// current offering: an enum case with an associated value and a static property of the same
/// name make `PaywallMode.automatic` ambiguous.
///
/// This type lives here, and not beside the RevenueCat paywall, so that an app can hold and
/// switch the setting without linking RevenueCatUI. Showing a RevenueCat paywall needs the
/// `SubscriptionRevenueCatUI` product.
public struct PaywallMode: Sendable, Hashable {
    private enum Kind: Sendable, Hashable {
        case custom
        case revenueCat
        case automatic
    }

    private let kind: Kind
    private let offering: String?
    private let placement: String?

    private init(_ kind: Kind, offering: String?, placement: String? = nil) {
        self.kind = kind
        self.offering = offering
        self.placement = placement
    }

    /// Always the app's own paywall. RevenueCat is not asked anything.
    public static let custom = PaywallMode(.custom, offering: nil)

    /// The RevenueCat paywall for the current offering.
    public static let revenueCat = PaywallMode(.revenueCat, offering: nil)

    /// The RevenueCat paywall for the current offering if it has one, the app's own otherwise.
    public static let automatic = PaywallMode(.automatic, offering: nil)

    /// The RevenueCat paywall for an offering, `nil` meaning the current one.
    ///
    /// Shown even when the offering has no paywall attached in the dashboard, in which case
    /// RevenueCatUI draws its default one from the offering's packages. Only an offering that
    /// cannot be found or loaded falls back to the app's own paywall.
    public static func revenueCat(offering: String?) -> PaywallMode {
        PaywallMode(.revenueCat, offering: offering)
    }

    /// The RevenueCat paywall when the offering has one attached in the dashboard, and the
    /// app's own paywall otherwise.
    ///
    /// The setting to ship with when the dashboard is where paywalls are designed but not every
    /// offering has one yet: attaching a paywall switches it on without an app release, and
    /// detaching it switches it off.
    public static func automatic(offering: String?) -> PaywallMode {
        PaywallMode(.automatic, offering: offering)
    }

    /// The RevenueCat paywall for the offering the dashboard serves at a placement.
    ///
    /// A placement names a spot in the app, such as `"feature_gate"`, so that Targeting can serve
    /// a different offering there, or none, without an app release. A placement the dashboard
    /// does not know falls back to the current offering, as RevenueCat's
    /// `Offerings.currentOffering(forPlacement:)` does; a placement set to serve nothing ends at
    /// the app's own paywall.
    public static func revenueCat(placement: String) -> PaywallMode {
        PaywallMode(.revenueCat, offering: nil, placement: placement)
    }

    /// The RevenueCat paywall for the offering served at a placement when that offering has a
    /// paywall attached, and the app's own paywall otherwise.
    public static func automatic(placement: String) -> PaywallMode {
        PaywallMode(.automatic, offering: nil, placement: placement)
    }

    /// The offering to look up, or `nil` for the current one or a placement's.
    ///
    /// Also `nil` for ``custom``, which looks nothing up; ask ``needsLookup`` to tell the two
    /// apart.
    public var offeringIdentifier: String? {
        kind == .custom ? nil : offering
    }

    /// The placement whose offering is looked up, or `nil` when the mode names an offering or
    /// the current one.
    public var placementIdentifier: String? {
        kind == .custom ? nil : placement
    }

    /// Whether ``choice(for:)`` depends on anything RevenueCat knows.
    ///
    /// `false` only for ``custom``, which shows the app's paywall straight away, without a
    /// loading state and without a network round trip.
    public var needsLookup: Bool {
        kind != .custom
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
        switch (kind, lookup) {
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
