import Foundation

/// The billing backend, narrowed to the calls this package makes.
///
/// Everything here reaches the store, which is what keeps `RevenueCatRepository` out of the
/// tests: the SDK cannot complete a purchase outside a real StoreKit session, so tests
/// substitute this protocol instead.
protocol SubscriptionRepository: Sendable {
    /// Reads the authoritative entitlement state from the store.
    func checkSubscriptionStatus() async throws -> SubscriptionStatus

    /// Fetches the offering the request names; `nil` when the dashboard has no such offering.
    func loadOffering(_ request: OfferingRequest) async throws -> SubscriptionOffering?

    /// Presents the purchase sheet for a package of the offering the request names and reports
    /// the entitlement once the purchase settles.
    func purchase(packageId: String, from request: OfferingRequest) async throws -> SubscriptionStatus

    /// Re-applies purchases on the Apple Account; resolves to `.inactive` when there are none.
    func restorePurchases() async throws -> SubscriptionStatus

    /// Attaches the billing identity to an app-level user identifier.
    func syncUser(userId: String) async throws

    /// Returns the billing identity to an anonymous one.
    func clearUser() async throws

    /// Records that the app's own paywall selling the offering the request names was shown;
    /// `paywallId` is where it was shown from.
    func trackPaywallImpression(paywallId: String, from request: OfferingRequest) async

    /// Streams entitlement changes pushed by the store, including ones this app did not cause.
    func observeSubscriptionChanges() -> AsyncStream<SubscriptionStatus>
}
