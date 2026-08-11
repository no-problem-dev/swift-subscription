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
