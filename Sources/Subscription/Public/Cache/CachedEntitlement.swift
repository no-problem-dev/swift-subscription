import Foundation

/// The last entitlement the store confirmed, in the form an ``EntitlementCache`` keeps it.
///
/// This is what a launch that cannot reach the store starts from. It records the identity the
/// reading belonged to, so a device that changes hands does not hand the entitlement over with
/// it, and when it was confirmed, so a stale reading can be recognised as one.
public struct CachedEntitlement: Sendable, Equatable, Codable {
    /// Whether the store said the customer was entitled.
    public let isActive: Bool

    /// The entitlement that granted access; `nil` when there was none.
    public let entitlementId: String?

    /// The store product backing the entitlement; `nil` when there was none.
    public let packageId: String?

    /// When access lapses. `nil` for a lifetime purchase, which never does.
    public let expirationDate: Date?

    /// The app-level identity the reading belonged to, or `nil` for the anonymous one.
    ///
    /// ``SubscriptionUseCase/syncUser(userId:)`` drops the whole record when this does not
    /// match the identity signing in.
    public let userId: String?

    /// When the store confirmed the reading.
    public let confirmedAt: Date

    /// Creates a record.
    ///
    /// - Parameters:
    ///   - isActive: Whether the store said the customer was entitled.
    ///   - entitlementId: The entitlement that granted access.
    ///   - packageId: The store product backing it.
    ///   - expirationDate: When access lapses; `nil` for a lifetime purchase.
    ///   - userId: The identity the reading belonged to.
    ///   - confirmedAt: When the store confirmed it.
    public init(
        isActive: Bool,
        entitlementId: String?,
        packageId: String?,
        expirationDate: Date?,
        userId: String?,
        confirmedAt: Date
    ) {
        self.isActive = isActive
        self.entitlementId = entitlementId
        self.packageId = packageId
        self.expirationDate = expirationDate
        self.userId = userId
        self.confirmedAt = confirmedAt
    }

    /// Records a status the store just confirmed.
    init(status: SubscriptionStatus, userId: String?, confirmedAt: Date) {
        self.init(
            isActive: status.isActive,
            entitlementId: status.activeEntitlementId,
            packageId: status.activePackageId,
            expirationDate: status.expirationDate,
            userId: userId,
            confirmedAt: confirmedAt
        )
    }

    /// The reading to run on until the store answers again.
    ///
    /// The rule ``SubscriptionUseCase/getSubscriptionStatus()`` applies to the cache, public so
    /// that a process without a use case — a widget or another extension reading the same
    /// ``EntitlementCache`` — reaches the same answer instead of reading ``isActive`` raw and
    /// either locking a subscriber out at the expiration date or never locking anyone out.
    /// Pass the ``SubscriptionConfiguration/gracePeriod`` the app configured.
    ///
    /// An entitlement that has passed its expiration date is honoured for `gracePeriod` beyond
    /// it and then stops: the customer paid up to a date, and the point of the grace is to
    /// survive a renewal this device has not been online to see, not to make a lapsed
    /// subscription permanent. A lifetime purchase has no expiration date and so never lapses.
    ///
    /// The grace is deliberately not applied to readings the store answered directly. The store
    /// runs its own billing-retry grace, during which it reports an active entitlement whose
    /// expiration date has already passed; clamping that would revoke access the store just
    /// granted.
    ///
    /// - Parameters:
    ///   - gracePeriod: How long past its expiration date the entitlement is honoured.
    ///   - now: The moment to answer for.
    /// - Returns: The reading, stamped ``EntitlementVerification/lastKnown(at:)``.
    public func lastKnownStatus(
        gracePeriod: TimeInterval = SubscriptionConfiguration.defaultGracePeriod,
        at now: Date = Date()
    ) -> SubscriptionStatus {
        let verification = EntitlementVerification.lastKnown(at: confirmedAt)

        guard isActive, isWithinGrace(gracePeriod: gracePeriod, at: now) else {
            return SubscriptionStatus(isActive: false, verification: verification)
        }

        return SubscriptionStatus(
            isActive: true,
            activeEntitlementId: entitlementId,
            activePackageId: packageId,
            expirationDate: expirationDate,
            verification: verification
        )
    }

    private func isWithinGrace(gracePeriod: TimeInterval, at now: Date) -> Bool {
        guard let expirationDate else { return true }
        return now <= expirationDate.addingTimeInterval(gracePeriod)
    }
}
