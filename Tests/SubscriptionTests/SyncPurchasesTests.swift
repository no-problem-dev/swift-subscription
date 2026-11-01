import XCTest
@testable import Subscription

/// Covers `syncPurchases()`, which sends the purchases on the Apple Account for the identity
/// signed in now, and that `syncUser` never syncs or restores on its own.
final class SyncPurchasesTests: XCTestCase {
    private static let activeStatus = SubscriptionStatus(
        isActive: true,
        activeEntitlementId: "premium",
        activePackageId: "com.example.annual",
        expirationDate: Date(timeIntervalSince1970: 1_900_000_000)
    )

    private static let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

    private static func makeUseCase(repository: SubscriptionRepository) -> SubscriptionUseCaseImpl {
        SubscriptionUseCaseImpl(repository: repository, now: { fixedNow })
    }

    func test_syncPurchasesの結果が状態キャッシュに反映される() async throws {
        let mock = SubscriptionRepositoryMock()
        await mock.setStatus(Self.activeStatus)
        let useCase = Self.makeUseCase(repository: mock)

        let returned = try await useCase.syncPurchases()

        XCTAssertEqual(returned, Self.activeStatus.confirmed(at: Self.fixedNow))
        let cached = await useCase.getSubscriptionStatus()
        XCTAssertEqual(cached, Self.activeStatus.confirmed(at: Self.fixedNow))
        let calls = await mock.syncPurchasesCallCount
        XCTAssertEqual(calls, 1)
    }

    /// The new identity's entitlement, as the store reports it after the sync, replaces what was
    /// read right after the swap.
    func test_サインイン後の同期で読んだ権利がキャッシュに入る() async throws {
        let mock = SubscriptionRepositoryMock()
        let useCase = Self.makeUseCase(repository: mock)

        try await useCase.syncUser(userId: "new-account")
        let afterSignIn = await useCase.getSubscriptionStatus()
        XCTAssertFalse(afterSignIn.isActive)

        await mock.setStatus(Self.activeStatus)
        let afterSync = try await useCase.syncPurchases()

        XCTAssertTrue(afterSync.isActive)
        let cached = await useCase.getSubscriptionStatus()
        XCTAssertTrue(cached.isActive)
    }

    /// `syncUser` runs on every launch to restore a session. Syncing or restoring from there would
    /// let devices sharing an Apple Account take the purchases from one another.
    func test_syncUserは購入を同期も復元もしない() async throws {
        let mock = SubscriptionRepositoryMock()
        let useCase = Self.makeUseCase(repository: mock)

        try await useCase.syncUser(userId: "user-1")
        try await useCase.syncUser(userId: "user-2")

        let calls = await mock.syncPurchasesCallCount
        XCTAssertEqual(calls, 0)
        let restores = await mock.restoreCallCount
        XCTAssertEqual(restores, 0)
    }

    func test_syncPurchasesが失敗しても状態キャッシュは変わらない() async throws {
        let mock = SubscriptionRepositoryMock()
        await mock.setStatus(Self.activeStatus)
        let useCase = Self.makeUseCase(repository: mock)
        _ = try await useCase.checkSubscriptionStatus()

        await mock.setError(SubscriptionError.userSyncFailed(URLError(.notConnectedToInternet)))
        do {
            _ = try await useCase.syncPurchases()
            XCTFail("エラーが投げられるべき")
        } catch SubscriptionError.userSyncFailed {
            // Expected.
        }

        let cached = await useCase.getSubscriptionStatus()
        XCTAssertEqual(cached, Self.activeStatus.confirmed(at: Self.fixedNow))
    }

    // MARK: - Default implementation

    private struct StandIn: SubscriptionUseCase {
        let status: SubscriptionStatus
        func observeSubscriptionStatus() -> AsyncStream<SubscriptionStatus> { AsyncStream { $0.finish() } }
        func getSubscriptionStatus() async -> SubscriptionStatus { .inactive }
        func checkSubscriptionStatus() async throws -> SubscriptionStatus { status }
        func loadOfferings() async throws -> SubscriptionOffering? { nil }
        func purchase(packageId: String) async throws -> SubscriptionStatus { .inactive }
        func restorePurchases() async throws -> SubscriptionStatus { .inactive }
        func syncUser(userId: String) async throws {}
        func clearUser() async throws {}
    }

    func test_既定の実装はcheckSubscriptionStatusで答える() async throws {
        let useCase = StandIn(status: Self.activeStatus)

        let returned = try await useCase.syncPurchases()

        XCTAssertEqual(returned, Self.activeStatus)
    }
}
