import Foundation

/// The RevenueCat-backed implementation of ``SubscriptionUseCase``.
///
/// Init configures the RevenueCat SDK as a side effect and starts a background task that
/// keeps the cached status current, so the instance is doing work from the moment it is
/// created. Create exactly one for the process and hand it out through the environment:
/// the underlying SDK is configured globally, and a second instance reconfigures it.
///
/// The observation task is cancelled on `deinit`.
public final class SubscriptionUseCaseImpl: SubscriptionUseCase {
    private let state: SubscriptionState
    private let repository: SubscriptionRepository
    private let observationTask: Task<Void, Never>

    /// Configures the RevenueCat SDK and begins tracking entitlement changes.
    ///
    /// Init does not reach the network and cannot fail; an unusable API key surfaces later as
    /// ``SubscriptionError/notConfigured`` from the first call that needs the store. The
    /// cached status is `.inactive` until the first refresh completes, so do not read
    /// ``getSubscriptionStatus()`` straight after init and treat the answer as final.
    ///
    /// - Parameter configuration: The RevenueCat API key and the entitlement identifier that
    ///   counts as subscribed.
    public convenience init(configuration: SubscriptionConfiguration) {
        self.init(repository: RevenueCatRepository(configuration: configuration))
    }

    /// Injects a repository directly. This is the seam that lets tests run without the SDK.
    init(repository: SubscriptionRepository) {
        let state = SubscriptionState()
        self.state = state
        self.repository = repository

        // **The task captures the state and the repository, never `self`.** The store's change
        // feed never finishes, so a task holding `self` would keep this instance alive for the
        // rest of the process and `deinit` — the only place the task is cancelled — would never
        // run.
        self.observationTask = Task {
            for await status in repository.observeSubscriptionChanges() {
                await state.setStatus(status)
            }
        }
    }

    deinit {
        observationTask.cancel()
    }

    // MARK: - SubscriptionUseCase

    public nonisolated func observeSubscriptionStatus() -> AsyncStream<SubscriptionStatus> {
        repository.observeSubscriptionChanges()
    }

    public nonisolated func getSubscriptionStatus() async -> SubscriptionStatus {
        await state.status
    }

    public func checkSubscriptionStatus() async throws -> SubscriptionStatus {
        let status = try await repository.checkSubscriptionStatus()
        await state.setStatus(status)
        return status
    }

    public func loadOfferings() async throws -> SubscriptionOffering? {
        try await repository.loadOfferings()
    }

    public func purchase(packageId: String) async throws -> SubscriptionStatus {
        let status = try await repository.purchase(packageId: packageId)
        await state.setStatus(status)
        return status
    }

    public func restorePurchases() async throws -> SubscriptionStatus {
        let status = try await repository.restorePurchases()
        await state.setStatus(status)
        return status
    }

    public func syncUser(userId: String) async throws {
        try await repository.syncUser(userId: userId)

        // Signing in swaps identities, so the entitlement read before the swap belongs to the
        // previous identity. **Discard it the moment the swap lands, not once the re-read
        // succeeds** — a re-read that throws would otherwise leave the previous account's
        // entitlement readable under the new identity.
        await state.setUserId(userId)
        await state.setStatus(.inactive)

        let status = try await repository.checkSubscriptionStatus()
        await state.setStatus(status)
    }

    public func clearUser() async throws {
        try await repository.clearUser()
        await state.setUserId(nil)
        await state.setStatus(.inactive)
    }

}
