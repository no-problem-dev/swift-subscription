import Foundation

/// Which offering a call reads, buys from, or records an impression of. `package` so
/// `SubscriptionRevenueCatUI` reads a placement through the same ``OfferingLookup``.
package enum OfferingRequest: Sendable, Equatable {
    /// The offering the dashboard marks current.
    case current
    /// The offering with this dashboard identifier, whether or not it is current.
    case identifier(String)
    /// The offering the dashboard serves at this placement, or the current one when it serves none.
    case placement(String)
    /// An offering already loaded, found again the way it was found.
    case loaded(id: String, servedBy: SubscriptionOffering.ServedBy)

    /// How to find `offering` again.
    package static func loaded(_ offering: SubscriptionOffering) -> OfferingRequest {
        .loaded(id: offering.id, servedBy: offering.servedBy)
    }
}
