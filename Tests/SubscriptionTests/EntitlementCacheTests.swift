import XCTest
@testable import Subscription

/// Covers the entitlement surviving a launch: what a cold start reads when the store cannot be
/// reached, how long a cached entitlement is honoured past its expiration date, and the cases
/// where it must be dropped rather than replayed.
final class EntitlementCacheTests: XCTestCase {
    /// When a previous launch confirmed the entitlement.
    private static let confirmedAt = Date(timeIntervalSince1970: 1_800_000_000)
    /// When the subscription lapses without a renewal: one day after that.
    private static let expiration = confirmedAt.addingTimeInterval(24 * 60 * 60)

    private static let day: TimeInterval = 24 * 60 * 60

    private static func record(
        isActive: Bool = true,
        expirationDate: Date? = expiration,
        userId: String? = nil
    ) -> CachedEntitlement {
        CachedEntitlement(
            isActive: isActive,
            entitlementId: "premium",
            packageId: "com.example.annual",
            expirationDate: expirationDate,
            userId: userId,
            confirmedAt: confirmedAt
        )
    }

    private static func makeUseCase(
        repository: SubscriptionRepository,
        entitlementCache: any EntitlementCache,
        gracePeriod: TimeInterval = SubscriptionConfiguration.defaultGracePeriod,
        now: Date
    ) -> SubscriptionUseCaseImpl {
        SubscriptionUseCaseImpl(
            repository: repository,
            entitlementCache: entitlementCache,
            gracePeriod: gracePeriod,
            now: { now }
        )
    }

    /// A repository that fails every entitlement read, which is what being out of signal looks
    /// like from inside this package.
    private static func offlineRepository() async -> SubscriptionRepositoryMock {
        let mock = SubscriptionRepositoryMock()
        await mock.setCheckStatusError(SubscriptionError.networkError(URLError(.notConnectedToInternet)))
        return mock
    }

    // MARK: - Out of signal

    /// The defect this cache exists for: a cold launch with no network used to answer
    /// `.inactive` for a paying customer, because the only thing that could have said otherwise
    /// was a call that failed.
    func test_圏外で確認に失敗しても前回確かめた権利で始まる() async {
        let cache = InMemoryEntitlementCache(entitlement: Self.record())
        let mock = await Self.offlineRepository()
        let useCase = Self.makeUseCase(
            repository: mock,
            entitlementCache: cache,
            now: Self.confirmedAt.addingTimeInterval(60)
        )

        do {
            _ = try await useCase.checkSubscriptionStatus()
            XCTFail("圏外なのだから投げるべき")
        } catch {
            // Expected.
        }

        let status = await useCase.getSubscriptionStatus()
        XCTAssertTrue(status.isActive, "確認が取れなくても、前回確かめた権利は残ること")
        XCTAssertEqual(status.verification, .lastKnown(at: Self.confirmedAt))
        XCTAssertEqual(status.activePackageId, "com.example.annual")
    }

    /// Replayed and confirmed readings unlock the same features, so the difference has to be
    /// legible somewhere. It is `verification`, not `isActive`.
    func test_キャッシュ由来か確認済みかを呼び出し側が見分けられる() async throws {
        let cache = InMemoryEntitlementCache(entitlement: Self.record())
        let mock = SubscriptionRepositoryMock()
        await mock.setStatus(SubscriptionStatus(isActive: true, activeEntitlementId: "premium"))
        let now = Self.confirmedAt.addingTimeInterval(60)
        let useCase = Self.makeUseCase(repository: mock, entitlementCache: cache, now: now)

        let beforeRefresh = await useCase.getSubscriptionStatus()
        XCTAssertEqual(beforeRefresh.verification, .lastKnown(at: Self.confirmedAt))

        _ = try await useCase.checkSubscriptionStatus()

        let afterRefresh = await useCase.getSubscriptionStatus()
        XCTAssertEqual(afterRefresh.verification, .confirmed(at: now))
    }

    /// Nothing cached is not the same as nothing bought.
    func test_キャッシュが空なら未確認として始まる() async {
        let useCase = Self.makeUseCase(
            repository: SubscriptionRepositoryMock(),
            entitlementCache: InMemoryEntitlementCache(),
            now: Self.confirmedAt
        )

        let status = await useCase.getSubscriptionStatus()

        XCTAssertEqual(status, .inactive)
        XCTAssertEqual(status.verification, .unverified)
    }

    // MARK: - Grace period

    func test_猶予の中なら期限を過ぎていても有効なまま() async {
        let cache = InMemoryEntitlementCache(entitlement: Self.record())
        let useCase = Self.makeUseCase(
            repository: SubscriptionRepositoryMock(),
            entitlementCache: cache,
            gracePeriod: 3 * Self.day,
            now: Self.expiration.addingTimeInterval(2 * Self.day)
        )

        let status = await useCase.getSubscriptionStatus()

        XCTAssertTrue(status.isActive, "期限切れから2日、猶予3日の中なので有効")
        XCTAssertEqual(status.verification, .lastKnown(at: Self.confirmedAt))
    }

    func test_猶予を過ぎたら落ちる() async {
        let cache = InMemoryEntitlementCache(entitlement: Self.record())
        let useCase = Self.makeUseCase(
            repository: SubscriptionRepositoryMock(),
            entitlementCache: cache,
            gracePeriod: 3 * Self.day,
            now: Self.expiration.addingTimeInterval(4 * Self.day)
        )

        let status = await useCase.getSubscriptionStatus()

        XCTAssertFalse(status.isActive, "猶予を過ぎたキャッシュで有料機能を開けてはいけない")
        XCTAssertEqual(
            status.verification,
            .lastKnown(at: Self.confirmedAt),
            "落ちた理由が『まだ確かめていない』ではなく『前回の値が古い』と分かること"
        )
    }

    /// A lifetime purchase has no expiration date, so there is nothing for the grace period to
    /// measure from and nothing to lapse.
    func test_買い切りは期限が無いのでいつまでも有効() async {
        let cache = InMemoryEntitlementCache(entitlement: Self.record(expirationDate: nil))
        let useCase = Self.makeUseCase(
            repository: SubscriptionRepositoryMock(),
            entitlementCache: cache,
            gracePeriod: 3 * Self.day,
            now: Self.confirmedAt.addingTimeInterval(365 * Self.day)
        )

        let status = await useCase.getSubscriptionStatus()

        XCTAssertTrue(status.isActive)
    }

    /// The grace is measured against the moment of the read, not the moment of the launch. A
    /// launch that stays open for days without ever reaching the store has to stop honouring
    /// the cached entitlement while it runs.
    func test_起動したまま猶予が切れたら落ちる() async {
        let cache = InMemoryEntitlementCache(entitlement: Self.record())
        let clock = MutableClock(now: Self.expiration)
        let useCase = SubscriptionUseCaseImpl(
            repository: SubscriptionRepositoryMock(),
            entitlementCache: cache,
            gracePeriod: 3 * Self.day,
            now: { clock.now }
        )

        let atLaunch = await useCase.getSubscriptionStatus()
        XCTAssertTrue(atLaunch.isActive)

        clock.now = Self.expiration.addingTimeInterval(4 * Self.day)

        let later = await useCase.getSubscriptionStatus()
        XCTAssertFalse(later.isActive, "起動中に猶予が切れたら、その場で落ちること")
    }

    /// The store runs a billing-retry grace of its own, during which it reports an active
    /// entitlement whose expiration date has already passed. Clamping that would revoke access
    /// the store granted a moment ago.
    func test_ストアが答えた権利には猶予を適用しない() async throws {
        let mock = SubscriptionRepositoryMock()
        let longExpired = Self.confirmedAt.addingTimeInterval(-365 * Self.day)
        await mock.setStatus(
            SubscriptionStatus(
                isActive: true,
                activeEntitlementId: "premium",
                activePackageId: "com.example.monthly",
                expirationDate: longExpired
            )
        )
        let useCase = Self.makeUseCase(
            repository: mock,
            entitlementCache: InMemoryEntitlementCache(),
            gracePeriod: 3 * Self.day,
            now: Self.confirmedAt
        )

        let returned = try await useCase.checkSubscriptionStatus()
        let cached = await useCase.getSubscriptionStatus()

        XCTAssertTrue(returned.isActive, "ストアが有効と答えたのだから有効")
        XCTAssertTrue(cached.isActive)
    }

    // MARK: - The injected place

    /// The whole point of injecting the cache: two use cases pointed at different places do not
    /// see each other's entitlement, and a real file is one of the places.
    func test_永続先は注入で差し替えられる() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "swift-subscription-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        let entitled = FileEntitlementCache(url: directory.appending(path: "entitled.json"))
        let empty = FileEntitlementCache(url: directory.appending(path: "empty.json"))

        // A launch that reaches the store writes what it confirmed to the place it was given.
        let mock = SubscriptionRepositoryMock()
        await mock.setStatus(
            SubscriptionStatus(
                isActive: true,
                activeEntitlementId: "premium",
                activePackageId: "com.example.annual",
                expirationDate: Self.expiration
            )
        )
        let firstLaunch = Self.makeUseCase(
            repository: mock,
            entitlementCache: entitled,
            now: Self.confirmedAt
        )
        _ = try await firstLaunch.checkSubscriptionStatus()

        // The next launch, out of signal, starts from that file.
        let offline = await Self.offlineRepository()
        let secondLaunch = Self.makeUseCase(
            repository: offline,
            entitlementCache: entitled,
            now: Self.confirmedAt.addingTimeInterval(60)
        )
        let replayed = await secondLaunch.getSubscriptionStatus()
        XCTAssertTrue(replayed.isActive, "同じファイルを渡した起動は権利を引き継ぐこと")
        XCTAssertEqual(replayed.verification, .lastKnown(at: Self.confirmedAt))

        // A use case pointed somewhere else knows nothing about it.
        let elsewhere = Self.makeUseCase(
            repository: offline,
            entitlementCache: empty,
            now: Self.confirmedAt.addingTimeInterval(60)
        )
        let unrelated = await elsewhere.getSubscriptionStatus()
        XCTAssertEqual(unrelated, .inactive, "別の置き場所を渡したら何も引き継がないこと")
    }

    // MARK: - Identity

    /// The identity rule the in-memory cache already enforced has to hold for the persisted one
    /// too, or the entitlement simply comes back on the next launch.
    func test_身元が変わったら永続した権利も消える() async throws {
        let cache = InMemoryEntitlementCache(entitlement: Self.record(userId: "previous-owner"))
        let mock = await Self.offlineRepository()
        let useCase = Self.makeUseCase(
            repository: mock,
            entitlementCache: cache,
            now: Self.confirmedAt.addingTimeInterval(60)
        )
        let before = await useCase.getSubscriptionStatus()
        XCTAssertTrue(before.isActive)

        // Sign-in lands; the entitlement read that follows it does not.
        do {
            try await useCase.syncUser(userId: "someone-else")
            XCTFail("再読み取りが失敗したのだから投げるべき")
        } catch {
            // Expected.
        }

        let after = await useCase.getSubscriptionStatus()
        XCTAssertEqual(after, .inactive, "身元が入れ替わった後に前の身元の権利が読めてはいけない")
        XCTAssertNil(cache.read(), "ディスクにも残してはいけない")
    }

    /// Signing the same person back in is not a swap. This is the offline relaunch: the app
    /// restores its own session, calls `syncUser` with the identity that is already on the
    /// record, and the entitlement this device confirmed before it lost signal is still there.
    func test_同じ身元で入り直しても権利は残る() async {
        let cache = InMemoryEntitlementCache(entitlement: Self.record(userId: "same-person"))
        let mock = await Self.offlineRepository()
        let useCase = Self.makeUseCase(
            repository: mock,
            entitlementCache: cache,
            now: Self.confirmedAt.addingTimeInterval(60)
        )

        do {
            try await useCase.syncUser(userId: "same-person")
            XCTFail("圏外なので再読み取りは失敗する")
        } catch {
            // Expected.
        }

        let status = await useCase.getSubscriptionStatus()
        XCTAssertTrue(status.isActive, "同じ身元で入り直しただけで権利を落としてはいけない")
        XCTAssertNotNil(cache.read())
    }

    func test_サインアウトで永続した権利も消える() async throws {
        let cache = InMemoryEntitlementCache(entitlement: Self.record(userId: "someone"))
        let useCase = Self.makeUseCase(
            repository: SubscriptionRepositoryMock(),
            entitlementCache: cache,
            now: Self.confirmedAt.addingTimeInterval(60)
        )

        try await useCase.clearUser()

        let status = await useCase.getSubscriptionStatus()
        XCTAssertEqual(status, .inactive)
        XCTAssertNil(cache.read(), "サインアウトしたら次の起動にも残さないこと")
    }

    // MARK: - What gets written

    func test_確認できた権利はそのまま次の起動へ残る() async throws {
        let cache = InMemoryEntitlementCache()
        let mock = SubscriptionRepositoryMock()
        await mock.setStatus(
            SubscriptionStatus(
                isActive: true,
                activeEntitlementId: "premium",
                activePackageId: "com.example.annual",
                expirationDate: Self.expiration
            )
        )
        let useCase = Self.makeUseCase(
            repository: mock,
            entitlementCache: cache,
            now: Self.confirmedAt
        )

        _ = try await useCase.checkSubscriptionStatus()

        let written = try XCTUnwrap(cache.read())
        XCTAssertEqual(written.isActive, true)
        XCTAssertEqual(written.packageId, "com.example.annual")
        XCTAssertEqual(written.expirationDate, Self.expiration)
        XCTAssertEqual(written.confirmedAt, Self.confirmedAt)
    }

    /// A confirmed lapse has to be written too. Storing only the good news would replay a
    /// cancelled subscription forever, since nothing would ever overwrite it.
    func test_権利が無いという確認も書き込まれる() async throws {
        let cache = InMemoryEntitlementCache(entitlement: Self.record())
        let mock = SubscriptionRepositoryMock()
        await mock.setStatus(.inactive)
        let useCase = Self.makeUseCase(
            repository: mock,
            entitlementCache: cache,
            now: Self.confirmedAt
        )

        _ = try await useCase.checkSubscriptionStatus()

        let written = try XCTUnwrap(cache.read())
        XCTAssertFalse(written.isActive, "解約が確認できたのに古い権利を残してはいけない")
    }

    func test_購入した権利はその場で次の起動へ残る() async throws {
        let cache = InMemoryEntitlementCache()
        let mock = SubscriptionRepositoryMock()
        await mock.setStatus(
            SubscriptionStatus(isActive: true, activeEntitlementId: "premium", expirationDate: Self.expiration)
        )
        let useCase = Self.makeUseCase(
            repository: mock,
            entitlementCache: cache,
            now: Self.confirmedAt
        )

        _ = try await useCase.purchase(packageId: "annual")

        XCTAssertEqual(cache.read()?.isActive, true)
    }
}

/// A clock a test can move.
private final class MutableClock: @unchecked Sendable {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}
