import Foundation
import RevenueCat

/// Finds the RevenueCat offering a request names, and how it was found.
///
/// Shared by the core and `SubscriptionRevenueCatUI` (hence `package`), so a placement is read the
/// same way whether the app draws the paywall or the dashboard does. `Offerings` cannot be built
/// outside the SDK, so its parts are passed in: `served` is `Offerings.currentOffering(forPlacement:)`,
/// which already answers with the placements' fallback offering for a placement the dashboard does
/// not list, and with `nil` when the project has no placements.
///
/// An identifier the dashboard does not have finds nothing. It never falls back to the current
/// offering: a paywall asked for one set of products and would be selling another. A placement
/// does fall back to the current offering, and says so with ``SubscriptionOffering/ServedBy/current``.
package enum OfferingLookup {
    package static func offering(
        for request: OfferingRequest,
        all: [String: Offering],
        current: Offering?,
        served: (String) -> Offering?
    ) -> (offering: Offering, servedBy: SubscriptionOffering.ServedBy)? {
        switch request {
        case .current:
            return current.map { ($0, .current) }
        case .identifier(let id):
            return all[id].map { ($0, .identifier) }
        case .placement(let placement):
            if let offering = served(placement) { return (offering, .placement(placement)) }
            return current.map { ($0, .current) }
        case .loaded(let id, let servedBy):
            // Prefer the copy that carries the placement or targeting context, but only while it is
            // still the offering the customer was shown; otherwise buy what was shown, by identifier.
            switch servedBy {
            case .placement(let placement):
                if let offering = served(placement), offering.identifier == id { return (offering, servedBy) }
            case .current:
                if let offering = current, offering.identifier == id { return (offering, .current) }
            case .identifier:
                break
            }
            return all[id].map { ($0, .identifier) }
        }
    }
}
