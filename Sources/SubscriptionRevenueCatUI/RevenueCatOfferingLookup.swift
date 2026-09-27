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

    /// What finding `offering` means for choosing a paywall.
    static func lookup(for offering: Offering?) -> PaywallOfferingLookup {
        guard let offering else { return .offeringMissing }
        return offering.hasPaywall ? .hasPaywall : .noPaywall
    }

    /// Loads the offering with this identifier, or the current one for `nil`.
    ///
    /// - Returns: The offering, or `nil` when the offerings loaded without it.
    /// - Throws: `SubscriptionError.notConfigured` before the SDK is configured, or
    ///   `SubscriptionError.networkError(_:)` when the offerings cannot be fetched.
    static func load(_ identifier: String?) async throws -> Offering? {
        guard Purchases.isConfigured else {
            throw SubscriptionError.notConfigured
        }

        let offerings: Offerings
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            throw SubscriptionError.networkError(error)
        }
        return offering(identifier, all: offerings.all, current: offerings.current)
    }
}
