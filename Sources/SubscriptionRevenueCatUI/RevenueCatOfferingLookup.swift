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
        OfferingLookup.offering(
            for: identifier.map(OfferingRequest.identifier) ?? .current,
            all: all,
            current: current,
            served: { _ in nil }
        )?.offering
    }

    /// The offering served at a placement when one is named, and otherwise the offering with
    /// this identifier, or the current one for `nil`.
    ///
    /// A placement is read as the core reads it (``OfferingLookup``), except that the core's
    /// fallback to the current offering is declined: a placement the dashboard serves nothing at
    /// finds nothing here, so the container shows the app's own paywall rather than whatever
    /// RevenueCat paywall the current offering carries.
    ///
    /// - Parameter served: What the dashboard serves at a placement: RevenueCat's
    ///   `Offerings.currentOffering(forPlacement:)`.
    static func offering(
        _ identifier: String?,
        placement: String?,
        all: [String: Offering],
        current: Offering?,
        served: (String) -> Offering?
    ) -> Offering? {
        guard let placement else { return offering(identifier, all: all, current: current) }
        guard let found = OfferingLookup.offering(for: .placement(placement), all: all, current: current, served: served),
              found.servedBy == .placement(placement) else { return nil }
        return found.offering
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
