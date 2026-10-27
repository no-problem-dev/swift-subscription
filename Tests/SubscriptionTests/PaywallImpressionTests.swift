import XCTest
@testable import Subscription

/// Covers telling RevenueCat that the app's own paywall was shown: the use case hands the store
/// where it was shown from and which offering it sells, once per call, and the protocol's default
/// implementation, for a stand-in that reaches no store, records nothing.
final class PaywallImpressionTests: XCTestCase {

    // MARK: - SubscriptionUseCaseImpl

    func test_出した場所を_paywallIdとしてストアに渡す() async {
        let mock = SubscriptionRepositoryMock()
        let useCase = SubscriptionUseCaseImpl(repository: mock)

        await useCase.trackPaywallImpression(source: "settings")

        let impressions = await mock.impressions
        XCTAssertEqual(impressions, [.init(paywallId: "settings", offeringId: nil)])
    }

    func test_IDを指定したofferingのペイウォールはそのIDで記録する() async {
        let mock = SubscriptionRepositoryMock()
        let useCase = SubscriptionUseCaseImpl(repository: mock)

        await useCase.trackPaywallImpression(source: "trip_limit", offeringId: "trip")

        let impressions = await mock.impressions
        XCTAssertEqual(impressions, [.init(paywallId: "trip_limit", offeringId: "trip")])
    }

    /// Each call is a separate impression on RevenueCat's side, so the use case must neither
    /// merge two presentations into one nor drop the second.
    func test_呼んだ回数だけ記録する() async {
        let mock = SubscriptionRepositoryMock()
        let useCase = SubscriptionUseCaseImpl(repository: mock)

        await useCase.trackPaywallImpression(source: "settings")
        await useCase.trackPaywallImpression(source: "onboarding")

        let impressions = await mock.impressions
        XCTAssertEqual(impressions.map(\.paywallId), ["settings", "onboarding"])
    }

    // MARK: - Default implementation

    /// A stand-in that implements none of the optional calls, as the apps' previews do.
    private struct StandIn: SubscriptionUseCase {
        func observeSubscriptionStatus() -> AsyncStream<SubscriptionStatus> { AsyncStream { $0.finish() } }
        func getSubscriptionStatus() async -> SubscriptionStatus { .inactive }
        func checkSubscriptionStatus() async throws -> SubscriptionStatus { .inactive }
        func loadOfferings() async throws -> SubscriptionOffering? { nil }
        func purchase(packageId: String) async throws -> SubscriptionStatus { .inactive }
        func restorePurchases() async throws -> SubscriptionStatus { .inactive }
        func syncUser(userId: String) async throws {}
        func clearUser() async throws {}
    }

    func test_既定の実装は何もせず戻る() async {
        let useCase = StandIn()

        await useCase.trackPaywallImpression(source: "settings")
        await useCase.trackPaywallImpression(source: "settings", offeringId: "trip")
    }

    /// A conformance that does record — an app's own test double — receives the one-argument
    /// form as a `nil` offering, so it can assert on a single entry point.
    func test_offeringを省いた形は_nilのofferingで呼ぶ() async {
        let recorder = Recorder()

        await recorder.trackPaywallImpression(source: "settings")

        let calls = await recorder.calls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls.first?.source, "settings")
        XCTAssertNil(calls.first?.offeringId)
    }

    private actor Recorder: SubscriptionUseCase {
        private(set) var calls: [(source: String, offeringId: String?)] = []

        nonisolated func observeSubscriptionStatus() -> AsyncStream<SubscriptionStatus> { AsyncStream { $0.finish() } }
        func getSubscriptionStatus() async -> SubscriptionStatus { .inactive }
        func checkSubscriptionStatus() async throws -> SubscriptionStatus { .inactive }
        func loadOfferings() async throws -> SubscriptionOffering? { nil }
        func purchase(packageId: String) async throws -> SubscriptionStatus { .inactive }
        func restorePurchases() async throws -> SubscriptionStatus { .inactive }
        func syncUser(userId: String) async throws {}
        func clearUser() async throws {}
        func trackPaywallImpression(source: String, offeringId: String?) async {
            calls.append((source, offeringId))
        }
    }
}
