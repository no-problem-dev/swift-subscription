import Foundation

/// サブスクリプションユースケースの実装
public final class SubscriptionUseCaseImpl: SubscriptionUseCase {
    private let state: SubscriptionState
    private let repository: SubscriptionRepository

    /// 初期化
    /// - Parameter configuration: サブスクリプション設定
    public init(configuration: SubscriptionConfiguration) {
        self.state = SubscriptionState()
        self.repository = RevenueCatRepository(configuration: configuration)

        // サブスクリプション状態の監視を開始
        Task {
            await self.startObservingSubscriptionChanges()
        }
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
        let offering = try await repository.loadOfferings()
        await state.setOfferings(offering)
        return offering
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

        // 同期後、サブスクリプション状態をチェック
        let status = try await repository.checkSubscriptionStatus()
        await state.setUserId(userId)
        await state.setStatus(status)
    }

    public func clearUser() async throws {
        try await repository.clearUser()
        await state.setUserId(nil)
        await state.setStatus(.inactive)
    }

    // MARK: - Private

    private func startObservingSubscriptionChanges() async {
        for await status in repository.observeSubscriptionChanges() {
            await state.setStatus(status)
        }
    }
}
