import Foundation

/// Whether the customer is entitled right now, and what backs that entitlement.
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

    /// Creates a status.
    ///
    /// Provided for tests and previews. Values that describe a real customer come from the
    /// use case; one constructed here is a fixture and grants nothing on its own.
    ///
    /// - Parameters:
    ///   - isActive: Whether paid features should be unlocked.
    ///   - activeEntitlementId: The entitlement that granted access.
    ///   - activePackageId: The store product backing the entitlement.
    ///   - expirationDate: When access lapses; `nil` for a lifetime purchase.
    public init(
        isActive: Bool,
        activeEntitlementId: String? = nil,
        activePackageId: String? = nil,
        expirationDate: Date? = nil
    ) {
        self.isActive = isActive
        self.activeEntitlementId = activeEntitlementId
        self.activePackageId = activePackageId
        self.expirationDate = expirationDate
    }

    /// The not-entitled reading, and the value the cache holds before the first refresh.
    public static let inactive = SubscriptionStatus(
        isActive: false,
        activeEntitlementId: nil,
        activePackageId: nil,
        expirationDate: nil
    )
}
