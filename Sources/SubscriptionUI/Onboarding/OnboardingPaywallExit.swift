import Foundation
import Subscription

/// How the customer left the paywall at the end of onboarding.
///
/// Every exit leads to the same place, the screen onboarding promised, so
/// ``OnboardingPaywallStep`` reports all four through one closure. The cases are here for the
/// analytics and for what the app does next, such as asking for notifications after a purchase.
public enum OnboardingPaywallExit: Sendable, Hashable {
    /// Closed with the × in the top-leading corner.
    case closeButton

    /// Closed with "Continue for free" beneath the paywall.
    case continueFree

    /// Bought a plan that lasts this long.
    case purchased(PackageDuration)

    /// Restored a purchase that entitles the customer.
    case restored

    /// Whether the customer leaves entitled.
    public var isEntitled: Bool {
        switch self {
        case .purchased, .restored: true
        case .closeButton, .continueFree: false
        }
    }

    /// The `result` of `paywall_closed`: `purchased`, `restored` or `dismissed`.
    public var result: String {
        switch self {
        case .closeButton, .continueFree: "dismissed"
        case .purchased: "purchased"
        case .restored: "restored"
        }
    }

    /// The `via` of `paywall_closed`: `close_button`, `continue_free`, or `auto` when the paywall
    /// closed itself after a purchase or a restore.
    public var via: String {
        switch self {
        case .closeButton: "close_button"
        case .continueFree: "continue_free"
        case .purchased, .restored: "auto"
        }
    }

    /// The `product` of `paywall_closed`: `yearly`, `monthly` or `lifetime`.
    ///
    /// `nil` unless a plan was bought, and for a plan whose duration this package does not model
    /// (`PackageDuration/unknown`), rather than a guess.
    public var product: String? {
        guard case .purchased(let duration) = self else { return nil }
        switch duration {
        case .annual: return "yearly"
        case .monthly: return "monthly"
        case .lifetime: return "lifetime"
        case .unknown: return nil
        }
    }
}
