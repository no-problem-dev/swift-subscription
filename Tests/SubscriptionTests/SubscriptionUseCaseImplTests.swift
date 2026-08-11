import XCTest
@testable import Subscription

/// Covers how `SubscriptionUseCaseImpl` updates its cached status, using an injected mock
/// repository in place of the store.
final class SubscriptionUseCaseImplTests: XCTestCase {
    private static let activeStatus = SubscriptionStatus(
        isActive: true,
        activeEntitlementId: "premium",
        activePackageId: "com.example.annual",
        expirationDate: Date(timeIntervalSince1970: 1_900_000_000)
    )

    // MARK: - Status cache updates

    func test_初期状態はinactive() async {
        let useCase = SubscriptionUseCaseImpl(repository: SubscriptionRepositoryMock())

        let status = await useCase.getSubscriptionStatus()

        XCTAssertEqual(status, .inactive)
    }

    func test_checkSubscriptionStatusの結果が状態キャッシュに反映される() async throws {
        let mock = SubscriptionRepositoryMock()
        await mock.setStatus(Self.activeStatus)
        let useCase = SubscriptionUseCaseImpl(repository: mock)

        let returned = try await useCase.checkSubscriptionStatus()

        XCTAssertEqual(returned, Self.activeStatus)
        let cached = await useCase.getSubscriptionStatus()
        XCTAssertEqual(cached, Self.activeStatus)
    }

    func test_checkSubscriptionStatusが失敗しても状態キャッシュは変わらない() async throws {
        let mock = SubscriptionRepositoryMock()
        await mock.setStatus(Self.activeStatus)
        let useCase = SubscriptionUseCaseImpl(repository: mock)
        _ = try await useCase.checkSubscriptionStatus()

        await mock.setError(SubscriptionError.notConfigured)
        do {
            _ = try await useCase.checkSubscriptionStatus()
            XCTFail("エラーが投げられるべき")
        } catch {
            // Expected.
        }

        let cached = await useCase.getSubscriptionStatus()
        XCTAssertEqual(cached, Self.activeStatus)
    }

    func test_purchaseの結果が状態キャッシュに反映される() async throws {
        let mock = SubscriptionRepositoryMock()
        await mock.setStatus(Self.activeStatus)
        let useCase = SubscriptionUseCaseImpl(repository: mock)

        let returned = try await useCase.purchase(packageId: "annual")

        XCTAssertEqual(returned, Self.activeStatus)
        let cached = await useCase.getSubscriptionStatus()
        XCTAssertEqual(cached, Self.activeStatus)
    }

    func test_restorePurchasesの結果が状態キャッシュに反映される() async throws {
        let mock = SubscriptionRepositoryMock()
        await mock.setStatus(Self.activeStatus)
        let useCase = SubscriptionUseCaseImpl(repository: mock)

        let returned = try await useCase.restorePurchases()

        XCTAssertEqual(returned, Self.activeStatus)
        let cached = await useCase.getSubscriptionStatus()
        XCTAssertEqual(cached, Self.activeStatus)
    }

    func test_syncUserは同期後の状態をキャッシュする() async throws {
        let mock = SubscriptionRepositoryMock()
        await mock.setStatus(Self.activeStatus)
        let useCase = SubscriptionUseCaseImpl(repository: mock)

        try await useCase.syncUser(userId: "user-1")

        let syncedUserIds = await mock.syncedUserIds
        XCTAssertEqual(syncedUserIds, ["user-1"])
        let cached = await useCase.getSubscriptionStatus()
        XCTAssertEqual(cached, Self.activeStatus)
    }

    func test_clearUserで状態キャッシュがinactiveに戻る() async throws {
        let mock = SubscriptionRepositoryMock()
        await mock.setStatus(Self.activeStatus)
        let useCase = SubscriptionUseCaseImpl(repository: mock)
        _ = try await useCase.checkSubscriptionStatus()

        try await useCase.clearUser()

        let clearUserCallCount = await mock.clearUserCallCount
        XCTAssertEqual(clearUserCallCount, 1)
        let cached = await useCase.getSubscriptionStatus()
        XCTAssertEqual(cached, .inactive)
    }

    func test_loadOfferingsはリポジトリのオファリングをそのまま返す() async throws {
        let mock = SubscriptionRepositoryMock()
        let offering = SubscriptionOffering(
            id: "default",
            packages: [
                SubscriptionPackage(
                    id: "annual",
                    title: "年間プラン",
                    description: "1年間のプレミアム",
                    price: "¥6,000",
                    pricePerMonth: "¥500",
                    duration: .annual
                )
            ]
        )
        await mock.setOffering(offering)
        let useCase = SubscriptionUseCaseImpl(repository: mock)

        let returned = try await useCase.loadOfferings()

        XCTAssertEqual(returned?.id, "default")
        XCTAssertEqual(returned?.packages.map(\.id), ["annual"])
    }

    // MARK: - Change stream propagation

    func test_リポジトリの変更ストリームが状態キャッシュに反映される() async {
        let mock = SubscriptionRepositoryMock()
        let useCase = SubscriptionUseCaseImpl(repository: mock)

        mock.changesContinuation.yield(Self.activeStatus)

        let reflected = await Self.waitUntil {
            await useCase.getSubscriptionStatus() == Self.activeStatus
        }
        XCTAssertTrue(reflected, "ストリームに流した状態がキャッシュに反映されること")
    }

    /// An identity swap must not leave the previous identity's entitlement readable.
    ///
    /// `syncUser` signs in and then re-reads, precisely so the value cached against the anonymous
    /// identity is not carried forward. When that re-read fails the re-read is skipped — and so is
    /// the discarding, so **the cache keeps answering with the entitlement of whoever was signed
    /// in before.** Someone who bought nothing keeps the access of the account they replaced.
    func test_同期に失敗しても直前の身元のエンタイトルメントは残らない() async throws {
        let mock = SubscriptionRepositoryMock()
        await mock.setStatus(Self.activeStatus)
        let useCase = SubscriptionUseCaseImpl(repository: mock)
        _ = try await useCase.checkSubscriptionStatus()
        let before = await useCase.getSubscriptionStatus()
        XCTAssertEqual(before, Self.activeStatus)

        // Sign-in lands; the entitlement read that follows it does not.
        await mock.setCheckStatusError(SubscriptionError.networkError(URLError(.notConnectedToInternet)))
        do {
            try await useCase.syncUser(userId: "someone-else")
            XCTFail("再読み取りが失敗したのだから投げるべき")
        } catch {
            // Expected.
        }

        let cached = await useCase.getSubscriptionStatus()
        XCTAssertEqual(cached, .inactive, "身元が入れ替わった後に前の身元の権利が読めてはいけない")
    }

    /// A dashboard with no offering marked current is reported as `nil`, not as a thrown error.
    ///
    /// Pins the contract that made a `offeringsNotAvailable` case misleading enough to delete: a
    /// caller who writes that `catch` believes the "nothing to sell" path is covered, and it never
    /// runs.
    func test_現在のオファリングが無いときは投げずにnilを返す() async throws {
        let useCase = SubscriptionUseCaseImpl(repository: SubscriptionRepositoryMock())

        let returned = try await useCase.loadOfferings()

        XCTAssertNil(returned)
    }

    // MARK: - Lifetime

    /// The observation task must not keep its own owner alive.
    ///
    /// `deinit` is where the task is cancelled, so a task that captures `self` strongly can never
    /// be cancelled by it: the instance is only released when the task ends, and the task only
    /// ends when the store's change feed does — which is never. **The documented cancellation
    /// point cannot be reached**, and the stream is consumed for the rest of the process.
    func test_解放されたら監視タスクも止まる() async {
        let mock = SubscriptionRepositoryMock()
        let box = await Self.makeThenRelease(repository: mock)

        // Give the runtime a turn, so a released instance has actually been torn down.
        for _ in 0..<10 { await Task.yield() }

        XCTAssertNil(box.value, "監視タスクが self を掴んだままなので deinit が走らない")
    }

    /// Holds the instance weakly, and returns after the only strong reference has gone out of
    /// scope. Taking the release across a function boundary keeps ARC from extending the lifetime
    /// to the end of the test.
    private final class WeakBox: @unchecked Sendable {
        weak var value: SubscriptionUseCaseImpl?
    }

    private static func makeThenRelease(repository: SubscriptionRepositoryMock) async -> WeakBox {
        let box = WeakBox()
        let useCase = SubscriptionUseCaseImpl(repository: repository)
        box.value = useCase
        // Let the observation task reach its suspension point on the change feed.
        _ = await useCase.getSubscriptionStatus()
        return box
    }

    // MARK: - Private

    private static func waitUntil(
        timeout: TimeInterval = 2,
        _ condition: @Sendable () async -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return false
    }
}
