import Foundation

/// Entitlement state and the purchase, restore, and sign-in calls that change it.
///
/// Two accessors report entitlement state and they are not interchangeable:
/// ``getSubscriptionStatus()`` answers from what is already known on the device and never
/// leaves it, while ``checkSubscriptionStatus()`` is the authoritative read that contacts the
/// store. Everything else here performs a network round trip.
///
/// Every status carries a ``SubscriptionStatus/verification`` saying which of those produced
/// it, so "the store says you are subscribed" and "the store said so last Tuesday and has not
/// been reachable since" are told apart rather than collapsed.
///
/// ## Example
/// ```swift
/// let offerings = try await subscriptionUseCase.loadOfferings()
/// if let package = offerings?.packages.first {
///     let status = try await subscriptionUseCase.purchase(packageId: package.id)
/// }
/// ```
public protocol SubscriptionUseCase: Sendable {
    /// Opens a stream that yields a new status on purchase, renewal, expiry, and restore.
    ///
    /// Each call opens its own stream; the store's own change feed is the source, so a
    /// value can arrive without this app having asked for one — a renewal processed
    /// overnight or a purchase made on another device both surface here.
    ///
    /// - Returns: A stream that stays open for the lifetime of the receiver. It finishes
    ///   immediately, without yielding, when the package was configured with an empty API key.
    func observeSubscriptionStatus() -> AsyncStream<SubscriptionStatus>

    /// Reads what is already known on the device, without contacting the store.
    ///
    /// Before the store has answered in this launch, this is the last entitlement it confirmed
    /// on this device, replayed from the ``EntitlementCache`` and reported as
    /// ``EntitlementVerification/lastKnown(at:)`` — which is what keeps a paying customer's
    /// features unlocked on a cold launch out of signal. An entitlement past its expiration
    /// date is replayed only for the configured grace period, and a lifetime one has no
    /// expiration date to pass.
    ///
    /// With nothing cached, the answer is `.inactive` with
    /// ``EntitlementVerification/unverified``, which means "not known yet" rather than "not
    /// subscribed". Gating paid features on the `isActive` of an unverified reading locks a
    /// subscriber out of what they bought until the first refresh lands.
    ///
    /// - Returns: The reading to run on at this moment.
    func getSubscriptionStatus() async -> SubscriptionStatus

    /// Fetches the authoritative status from the store and refreshes the cache.
    ///
    /// This is the call to trust when the answer decides whether someone keeps access.
    /// A thrown error leaves the previous reading in place rather than clearing it, so a failed
    /// refresh does not revoke access from a subscriber who is merely offline.
    ///
    /// A successful read is written to the ``EntitlementCache``, which is what makes it
    /// survive to the next launch. It is reported verbatim, without the grace period applied:
    /// the store runs a billing-retry grace of its own during which it reports an active
    /// entitlement whose expiration date has already passed, and clamping that here would
    /// revoke access the store just granted.
    ///
    /// - Returns: The current entitlement state as the store reports it.
    /// - Throws: ``SubscriptionError/networkError(_:)`` if the store cannot be reached,
    ///   or ``SubscriptionError/notConfigured`` if the API key was empty at init.
    func checkSubscriptionStatus() async throws -> SubscriptionStatus

    /// Fetches the products to display on a paywall.
    ///
    /// - Returns: The offering marked current in the RevenueCat dashboard, or `nil` when no
    ///   offering is marked current. `nil` is a dashboard configuration problem, not a
    ///   transport failure, and it leaves a paywall with nothing to sell.
    /// - Throws: ``SubscriptionError/networkError(_:)`` if the products cannot be fetched.
    func loadOfferings() async throws -> SubscriptionOffering?

    /// Presents the system purchase sheet for one package and refreshes the cache on success.
    ///
    /// - Parameter packageId: A ``SubscriptionPackage/id`` from ``loadOfferings()``. This is
    ///   the offering's package identifier, not an App Store product identifier; passing a
    ///   product identifier throws ``SubscriptionError/packageNotFound(_:)``.
    /// - Returns: The entitlement state after the purchase settles.
    /// - Throws: ``SubscriptionError/purchaseCancelled`` when the customer dismisses the
    ///   sheet. That is an ordinary outcome, not a failure — surfacing it as an error alert
    ///   is the most common mistake here.
    func purchase(packageId: String) async throws -> SubscriptionStatus

    /// Re-applies purchases already tied to the signed-in Apple Account.
    ///
    /// Returning normally is not evidence of an entitlement: when there is nothing to
    /// restore this succeeds and returns `.inactive`. Branch on the returned
    /// ``SubscriptionStatus/isActive``, not on the absence of a thrown error, or a customer
    /// who never subscribed will be told their purchases were restored.
    ///
    /// - Returns: The entitlement state after the restore.
    /// - Throws: ``SubscriptionError/restoreFailed(_:)`` if the store rejects the request.
    func restorePurchases() async throws -> SubscriptionStatus

    /// Binds subsequent purchases to an app-level user identifier and refreshes the cache.
    ///
    /// Call this after the customer signs in. Until it is called, purchases are attributed
    /// to an anonymous identity, so an entitlement bought before sign-in does not follow the
    /// account to another device.
    ///
    /// The entitlement is discarded — from memory and from the ``EntitlementCache`` — as soon as
    /// the identity swaps, and refilled by the refresh that follows. A throwing call therefore
    /// leaves nothing readable rather than the previous account's entitlement: "not known yet"
    /// for the new identity, not a grant inherited from the old one.
    ///
    /// Passing the identity that is already signed in is not a swap and discards nothing. That
    /// is what a relaunch out of signal does — the app signs the same person back in, and the
    /// entitlement this device confirmed before it lost signal is still there.
    ///
    /// - Parameter userId: The app's stable identifier for the signed-in account.
    /// - Throws: ``SubscriptionError/userSyncFailed(_:)`` if sign-in is rejected, or
    ///   ``SubscriptionError/networkError(_:)`` if the refresh after sign-in cannot reach the store.
    func syncUser(userId: String) async throws

    /// Returns to an anonymous identity and forgets the entitlement, in memory and in the
    /// ``EntitlementCache``.
    ///
    /// Call this on sign-out. Skipping it leaves the previous account's entitlement readable
    /// by whoever signs in next on the same device — and, now that the entitlement outlives the
    /// process, readable on the next launch too.
    ///
    /// - Throws: ``SubscriptionError/userSyncFailed(_:)`` if sign-out is rejected.
    func clearUser() async throws
}
