import Foundation

/// The billing backend, narrowed to the calls this package makes.
///
/// Everything here reaches the store, which is what keeps `RevenueCatRepository` out of the
/// tests: the SDK cannot complete a purchase outside a real StoreKit session, so tests
/// substitute this protocol instead.
protocol SubscriptionRepository: Sendable {
    /// Reads the authoritative entitlement state from the store.
    func checkSubscriptionStatus() async throws -> SubscriptionStatus

    /// Fetches the currently marked offering, or `nil` when the dashboard marks none.
    func loadOfferings() async throws -> SubscriptionOffering?

    /// Presents the purchase sheet and reports the entitlement once the purchase settles.
    func purchase(packageId: String) async throws -> SubscriptionStatus

    /// Re-applies purchases on the Apple Account; resolves to `.inactive` when there are none.
    func restorePurchases() async throws -> SubscriptionStatus

    /// Attaches the billing identity to an app-level user identifier.
    func syncUser(userId: String) async throws

    /// Returns the billing identity to an anonymous one.
    func clearUser() async throws

    /// Streams entitlement changes pushed by the store, including ones this app did not cause.
    func observeSubscriptionChanges() -> AsyncStream<SubscriptionStatus>
}
