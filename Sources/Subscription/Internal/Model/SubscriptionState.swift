import Foundation

/// The entitlement this process is running on, and the record a later launch will start from.
///
/// An actor because the store's change feed and app code both write here, and because the
/// cache behind it must not be written from two places at once.
///
/// Two readings live here and they are not the same thing. `confirmedStatus` is what the store
/// answered in *this* process and is reported verbatim. `record` is the last reading the store
/// confirmed on this device, which may be from a previous launch; it is only reported while the
/// store has not answered yet, and it is clamped by the grace period on the way out.
actor SubscriptionState {
    private let cache: any EntitlementCache
    private let gracePeriod: TimeInterval

    private var confirmedStatus: SubscriptionStatus?
    private var record: CachedEntitlement?
    private(set) var userId: String?

    /// Starts from whatever the cache holds, so a launch that never reaches the store still
    /// knows what the store last said.
    init(cache: any EntitlementCache, gracePeriod: TimeInterval) {
        self.cache = cache
        self.gracePeriod = gracePeriod
        self.record = cache.read()
        self.userId = record?.userId
    }

    // MARK: - Reading

    /// The entitlement to run on at this moment.
    ///
    /// `now` is a parameter rather than a call to `Date()` so that a long-running launch that
    /// never reaches the store stops honouring a cached entitlement once the grace runs out,
    /// instead of holding the answer it resolved at startup for the life of the process.
    func status(at now: Date) -> SubscriptionStatus {
        if let confirmedStatus {
            return confirmedStatus
        }
        guard let record else { return .inactive }
        return record.lastKnownStatus(gracePeriod: gracePeriod, at: now)
    }

    // MARK: - Writing

    /// Takes a reading the store answered: it becomes what this process runs on, and what the
    /// next launch will start from.
    ///
    /// - Returns: The same reading, stamped as confirmed at `now`.
    @discardableResult
    func confirm(_ status: SubscriptionStatus, at now: Date) -> SubscriptionStatus {
        let confirmed = status.confirmed(at: now)
        confirmedStatus = confirmed

        let record = CachedEntitlement(status: confirmed, userId: userId, confirmedAt: now)
        self.record = record
        cache.write(record)

        return confirmed
    }

    /// Points the state at the identity signing in, dropping everything the previous one left
    /// behind — in memory and in the cache both.
    ///
    /// Nothing is dropped when the identity is unchanged, which is what makes an offline
    /// re-launch work: the app signs the same person back in and the entitlement confirmed
    /// before the device lost signal is still there.
    func swapIdentity(to userId: String) {
        guard userId != self.userId else { return }

        self.userId = userId
        confirmedStatus = nil
        record = nil
        cache.clear()
    }

    /// Returns to the anonymous identity and forgets the entitlement, for a sign-out.
    ///
    /// Unconditional, unlike ``swapIdentity(to:)``: signing out is a request to leave nothing
    /// behind, whoever was signed in.
    func forget() {
        userId = nil
        confirmedStatus = nil
        record = nil
        cache.clear()
    }
}
