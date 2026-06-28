import Foundation

/// `SubscriptionUseCase` の RevenueCat バックエンド実装。
///
/// `RevenueCatRepository` を介して App Store の課金処理を行い、
/// 内部の `SubscriptionState` アクターでサブスクリプション状態をキャッシュする。
///
/// 初期化時に RevenueCat SDK を設定し、バックグラウンドでサブスクリプション状態の
/// 変化を監視するタスクを起動する。インスタンスを破棄すると監視タスクは自動的に
/// キャンセルされる。
///
/// - Note: このクラスは `Sendable` に準拠しており、Swift Concurrency 環境で安全に使用できる。
///   インスタンスは通常アプリのルートで 1 つ生成し、環境値経由で配布する。
public final class SubscriptionUseCaseImpl: SubscriptionUseCase {
    private let state: SubscriptionState
    private let repository: SubscriptionRepository
    nonisolated(unsafe) private var observationTask: Task<Void, Never>?

    /// `SubscriptionConfiguration` を使ってインスタンスを生成する。
    ///
    /// RevenueCat SDK を設定し、サブスクリプション状態の変化を
    /// バックグラウンドで継続的に監視するタスクを起動する。
    ///
    /// - Parameter configuration: RevenueCat API キーとエンタイトルメント ID を含む設定値。
    public init(configuration: SubscriptionConfiguration) {
        self.state = SubscriptionState()
        self.repository = RevenueCatRepository(configuration: configuration)

        // サブスクリプション状態の監視を開始
        self.observationTask = Task {
            await self.startObservingSubscriptionChanges()
        }
    }

    deinit {
        observationTask?.cancel()
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
