import Foundation

/// Whether the customer is entitled right now, what backs that entitlement, and how the
/// answer was obtained.
///
/// A value is a reading taken at one moment, not a live view. Nothing in it expires on its
/// own, so a value held across a subscription lapse keeps reporting `isActive`. Re-read it
/// from ``SubscriptionUseCase/observeSubscriptionStatus()`` or a refresh instead of storing
/// one and trusting it later.
public struct SubscriptionStatus: Sendable, Equatable {
    /// Whether paid features should be unlocked.
    ///
    /// This is the only field to branch on for access. The others describe the entitlement
    /// and are `nil` whenever this is `false`.
    public let isActive: Bool

    /// The entitlement that granted access, matching the identifier given at configuration.
    public let activeEntitlementId: String?

    /// The store product backing the entitlement, which is how to tell a monthly subscriber
    /// from an annual or lifetime one.
    public let activePackageId: String?

    /// When access lapses without a renewal.
    ///
    /// `nil` for a lifetime purchase as well as for no subscription, so it does not
    /// distinguish the two — check `isActive` first. A date in the past can still appear
    /// alongside `isActive == true` during the store's grace period for a failed payment.
    public let expirationDate: Date?

    /// Where this reading came from: the store, the cache, or nowhere yet.
    ///
    /// Access does not depend on it — a reading replayed from the cache unlocks exactly what a
    /// confirmed one does — but telling "not subscribed" apart from "not known yet" does, and
    /// so does anything the app says out loud about the state of the subscription.
    public let verification: EntitlementVerification

    /// Creates a status.
    ///
    /// Provided for tests and previews. Values that describe a real customer come from the
    /// use case; one constructed here is a fixture and grants nothing on its own, which is why
    /// `verification` defaults to ``EntitlementVerification/unverified``.
    ///
    /// - Parameters:
    ///   - isActive: Whether paid features should be unlocked.
    ///   - activeEntitlementId: The entitlement that granted access.
    ///   - activePackageId: The store product backing the entitlement.
    ///   - expirationDate: When access lapses; `nil` for a lifetime purchase.
    ///   - verification: Where the reading came from. Defaults to `.unverified`.
    public init(
        isActive: Bool,
        activeEntitlementId: String? = nil,
        activePackageId: String? = nil,
        expirationDate: Date? = nil,
        verification: EntitlementVerification = .unverified
    ) {
        self.isActive = isActive
        self.activeEntitlementId = activeEntitlementId
        self.activePackageId = activePackageId
        self.expirationDate = expirationDate
        self.verification = verification
    }

    /// The not-entitled, never-verified reading: what a first launch holds before anything has
    /// been read and with nothing in the cache.
    public static let inactive = SubscriptionStatus(
        isActive: false,
        activeEntitlementId: nil,
        activePackageId: nil,
        expirationDate: nil,
        verification: .unverified
    )

    /// The same reading, stamped as one the store answered at this moment.
    ///
    /// The repository reports what the entitlement *is*; only the use case knows when it was
    /// asked, so the stamp is applied there rather than at the store boundary.
    func confirmed(at date: Date) -> SubscriptionStatus {
        SubscriptionStatus(
            isActive: isActive,
            activeEntitlementId: activeEntitlementId,
            activePackageId: activePackageId,
            expirationDate: expirationDate,
            verification: .confirmed(at: date)
        )
    }
}
