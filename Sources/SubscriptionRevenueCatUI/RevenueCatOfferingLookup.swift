import Foundation
import RevenueCat
import Subscription
import SubscriptionUI

/// Finds the offering a paywall asked for and says whether it has a RevenueCat paywall.
///
/// The SDK is never asked anything before `Purchases.isConfigured` is true. `Purchases.shared`
/// traps when nothing configured it, which is the state an app is in while it runs on a stub
/// `SubscriptionUseCase` or with an empty API key.
enum RevenueCatOfferingLookup {
    /// The offering with this identifier, or the current one for `nil`.
    static func offering(
        _ identifier: String?,
        all: [String: Offering],
        current: Offering?
    ) -> Offering? {
        guard let identifier else { return current }
        return all[identifier]
    }

    /// The offering served at a placement when one is named, and otherwise the offering with
    /// this identifier, or the current one for `nil`.
    ///
    /// - Parameter served: What the dashboard serves at a placement: RevenueCat's
    ///   `Offerings.currentOffering(forPlacement:)`, which already falls back to the current
    ///   offering for a placement it does not know.
    static func offering(
        _ identifier: String?,
        placement: String?,
        all: [String: Offering],
        current: Offering?,
        served: (String) -> Offering?
    ) -> Offering? {
        guard let placement else { return offering(identifier, all: all, current: current) }
        return served(placement)
    }

    /// What finding `offering` means for choosing a paywall.
    static func lookup(for offering: Offering?) -> PaywallOfferingLookup {
        guard let offering else { return .offeringMissing }
        return offering.hasPaywall ? .hasPaywall : .noPaywall
    }

    /// Loads the offering served at the placement, or else the offering with this identifier,
    /// or the current one for `nil`.
    ///
    /// - Returns: The offering, or `nil` when the offerings loaded without it.
    /// - Throws: `SubscriptionError.notConfigured` before the SDK is configured, or
    ///   `SubscriptionError.networkError(_:)` when the offerings cannot be fetched.
    static func load(_ identifier: String?, placement: String? = nil) async throws -> Offering? {
        guard Purchases.isConfigured else {
            throw SubscriptionError.notConfigured
        }

        let offerings: Offerings
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            throw SubscriptionError.networkError(error)
        }
        return offering(
            identifier,
            placement: placement,
            all: offerings.all,
            current: offerings.current,
            served: { offerings.currentOffering(forPlacement: $0) }
        )
    }
}
