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
    private let now: @Sendable () -> Date
    private let observationTask: Task<Void, Never>

    /// Configures the RevenueCat SDK and begins tracking entitlement changes.
    ///
    /// Init does not reach the network and cannot fail; an unusable API key surfaces later as
    /// ``SubscriptionError/notConfigured`` from the first call that needs the store. It does
    /// read `entitlementCache`, so ``getSubscriptionStatus()`` answers with the entitlement the
    /// store last confirmed on this device from the first moment, without waiting for a
    /// network call that may never succeed.
    ///
    /// - Parameters:
    ///   - configuration: The RevenueCat API key, the entitlement identifier that counts as
    ///     subscribed, and how long a cached entitlement survives past its expiration date.
    ///   - entitlementCache: Where to keep the last confirmed entitlement between launches.
    ///     There is no default: a cache is the difference between a paying customer keeping
    ///     access out of signal and being shown a paywall, and only the app knows where its
    ///     own storage belongs. ``InMemoryEntitlementCache`` opts out, at that cost.
    public convenience init(
        configuration: SubscriptionConfiguration,
        entitlementCache: any EntitlementCache
    ) {
        self.init(
            repository: RevenueCatRepository(configuration: configuration),
            entitlementCache: entitlementCache,
            gracePeriod: configuration.gracePeriod
        )
    }

    /// Injects a repository, a cache and a clock directly. This is the seam that lets tests run
    /// without the SDK, without touching disk, and without waiting for real time to pass.
    init(
        repository: SubscriptionRepository,
        entitlementCache: any EntitlementCache = InMemoryEntitlementCache(),
        gracePeriod: TimeInterval = SubscriptionConfiguration.defaultGracePeriod,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        let state = SubscriptionState(cache: entitlementCache, gracePeriod: gracePeriod)
        self.state = state
        self.repository = repository
        self.now = now

        // **The task captures the state, the repository and the clock, never `self`.** The
        // store's change feed never finishes, so a task holding `self` would keep this instance
        // alive for the rest of the process and `deinit` — the only place the task is cancelled
        // — would never run.
        self.observationTask = Task {
            for await status in repository.observeSubscriptionChanges() {
                await state.confirm(status, at: now())
            }
        }
    }

    deinit {
        observationTask.cancel()
    }

    // MARK: - SubscriptionUseCase

    public nonisolated func observeSubscriptionStatus() -> AsyncStream<SubscriptionStatus> {
        // Stamped on the way out, so a status taken from the stream carries the same
        // provenance as one returned by `checkSubscriptionStatus()`. The stream and the clock
        // are captured as values; `self` is not, for the reason `init` gives.
        let changes = repository.observeSubscriptionChanges()
        let now = self.now

        return AsyncStream { continuation in
            let task = Task {
                for await status in changes {
                    continuation.yield(status.confirmed(at: now()))
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public nonisolated func getSubscriptionStatus() async -> SubscriptionStatus {
        await state.status(at: now())
    }

    public func checkSubscriptionStatus() async throws -> SubscriptionStatus {
        let status = try await repository.checkSubscriptionStatus()
        return await state.confirm(status, at: now())
    }

    public func loadOfferings() async throws -> SubscriptionOffering? {
        try await repository.loadOffering(id: nil)
    }

    public func loadOffering(id: String) async throws -> SubscriptionOffering? {
        try await repository.loadOffering(id: id)
    }

    public func purchase(packageId: String) async throws -> SubscriptionStatus {
        let status = try await repository.purchase(packageId: packageId, offeringId: nil)
        return await state.confirm(status, at: now())
    }

    public func purchase(packageId: String, inOffering offeringId: String) async throws -> SubscriptionStatus {
        let status = try await repository.purchase(packageId: packageId, offeringId: offeringId)
        return await state.confirm(status, at: now())
    }

    public func restorePurchases() async throws -> SubscriptionStatus {
        let status = try await repository.restorePurchases()
        return await state.confirm(status, at: now())
    }

    public func syncUser(userId: String) async throws {
        try await repository.syncUser(userId: userId)

        // Signing in swaps identities, so the entitlement read before the swap belongs to the
        // previous identity. **Discard it the moment the swap lands, not once the re-read
        // succeeds** — a re-read that throws would otherwise leave the previous account's
        // entitlement readable under the new identity. The cached record goes with it.
        //
        // Signing the *same* identity back in is not a swap and discards nothing, which is what
        // lets a relaunch out of signal keep the entitlement this device already confirmed.
        await state.swapIdentity(to: userId)

        let status = try await repository.checkSubscriptionStatus()
        await state.confirm(status, at: now())
    }

    public func clearUser() async throws {
        try await repository.clearUser()
        await state.forget()
    }

}
