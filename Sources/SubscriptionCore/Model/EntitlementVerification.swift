import Foundation

/// Where a ``SubscriptionStatus`` came from, and when.
///
/// A reading the store answered and a reading replayed from the cache both unlock the same
/// features, so ``SubscriptionStatus/isActive`` is still the only field to branch on for
/// access. This is the field to branch on for *wording*: a screen that says "your
/// subscription is active" is claiming something only ``confirmed(at:)`` supports.
public enum EntitlementVerification: Sendable, Equatable {
    /// The store answered this reading, at this moment.
    case confirmed(at: Date)

    /// The store has not answered in this launch, so this is the last reading it did confirm,
    /// replayed from the cache and still inside the grace period.
    ///
    /// The date is when the store last confirmed it, which can be a long time ago — a device
    /// that has been offline since it was last opened is the whole reason this case exists.
    case lastKnown(at: Date)

    /// Nothing has been confirmed on this device yet, and nothing was cached.
    ///
    /// The state a first launch starts in. It means "not known", not "not subscribed": a
    /// paywall shown on this alone is shown to paying customers too.
    case unverified

    /// When the store confirmed the reading, or `nil` when it never has.
    public var verifiedAt: Date? {
        switch self {
        case .confirmed(let date), .lastKnown(let date):
            return date
        case .unverified:
            return nil
        }
    }
}
