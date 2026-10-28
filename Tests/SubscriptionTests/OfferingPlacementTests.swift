import RevenueCat
import XCTest
@testable import Subscription

/// Covers placements and metadata: which RevenueCat offering a request finds and how it says so,
/// the use case handing the request through, the protocol's defaults for a conformance that knows
/// one offering, and keeping only the string values of the dashboard's metadata.
final class OfferingPlacementTests: XCTestCase {
    private static func offering(_ identifier: String) -> Offering {
        Offering(identifier: identifier, serverDescription: identifier, availablePackages: [], webCheckoutUrl: nil)
    }

    private static let current = offering("default")
    private static let gate = offering("gate")
    private static let all = ["default": current, "gate": gate, "trip": offering("trip")]

    private static func find(
        _ request: OfferingRequest,
        current: Offering? = OfferingPlacementTests.current,
        served: (String) -> Offering? = { $0 == "feature_gate" ? OfferingPlacementTests.gate : nil }
    ) -> (id: String, servedBy: SubscriptionOffering.ServedBy)? {
        OfferingLookup.offering(for: request, all: all, current: current, served: served)
            .map { ($0.offering.identifier, $0.servedBy) }
    }

    // MARK: - OfferingLookup

    func test_placementに配られたofferingはplacementとして返す() {
        let found = Self.find(.placement("feature_gate"))
        XCTAssertEqual(found?.id, "gate")
        XCTAssertEqual(found?.servedBy, .placement("feature_gate"))
    }

    func test_placementに何も配られていなければcurrentとして返す() {
        let found = Self.find(.placement("unknown"))
        XCTAssertEqual(found?.id, "default")
        XCTAssertEqual(found?.servedBy, .current)
    }

    func test_placementに何も無くcurrentも無ければnil() {
        XCTAssertNil(Self.find(.placement("unknown"), current: nil))
    }

    func test_IDの指定はcurrentで代用しない() {
        XCTAssertEqual(Self.find(.identifier("trip"))?.servedBy, .identifier)
        XCTAssertNil(Self.find(.identifier("winter")))
        XCTAssertEqual(Self.find(.current)?.id, "default")
    }

    /// Buying from a placement's offering finds the copy the placement serves, which carries the
    /// placement to RevenueCat.
    func test_placementで読んだofferingはplacementから買い直す() {
        let found = Self.find(.loaded(id: "gate", servedBy: .placement("feature_gate")))
        XCTAssertEqual(found?.id, "gate")
        XCTAssertEqual(found?.servedBy, .placement("feature_gate"))
    }

    /// The dashboard moved the placement to another offering after the paywall loaded: the
    /// customer is still sold what they were shown.
    func test_placementの割り当てが変わっていたら見せたofferingをIDで買う() {
        let found = Self.find(.loaded(id: "trip", servedBy: .placement("feature_gate")))
        XCTAssertEqual(found?.id, "trip")
        XCTAssertEqual(found?.servedBy, .identifier)
    }

    func test_currentとして読んだofferingは今もcurrentならcurrentから買う() {
        XCTAssertEqual(Self.find(.loaded(id: "default", servedBy: .current))?.servedBy, .current)
        XCTAssertEqual(Self.find(.loaded(id: "trip", servedBy: .current))?.servedBy, .identifier)
    }

    // MARK: - SubscriptionUseCaseImpl

    func test_placementの読み込みと購入と表示はその聞き方でストアに渡す() async throws {
        let mock = SubscriptionRepositoryMock()
        let served = SubscriptionOffering(id: "gate", packages: [], metadata: [:], servedBy: .placement("feature_gate"))
        await mock.setOffering(served)
        let useCase = SubscriptionUseCaseImpl(repository: mock)

        let loaded = try await useCase.loadOffering(placement: "feature_gate")
        _ = try await useCase.purchase(packageId: "$rc_annual", from: try XCTUnwrap(loaded))
        await useCase.trackPaywallImpression(source: "gate", offering: try XCTUnwrap(loaded))

        let loadRequests = await mock.loadRequests
        let purchasedFrom = await mock.purchasedFrom
        let impressions = await mock.impressions
        XCTAssertEqual(loadRequests, [.placement("feature_gate")])
        XCTAssertEqual(purchasedFrom, [.loaded(id: "gate", servedBy: .placement("feature_gate"))])
        XCTAssertEqual(impressions, [.init(paywallId: "gate", request: .loaded(id: "gate", servedBy: .placement("feature_gate")))])
    }

    // MARK: - Default implementation

    private actor SingleOffering: SubscriptionUseCase {
        let offering: SubscriptionOffering?
        private(set) var purchasedFrom: [String] = []
        private(set) var impressions: [String?] = []

        init(offering: SubscriptionOffering?) { self.offering = offering }

        nonisolated func observeSubscriptionStatus() -> AsyncStream<SubscriptionStatus> { AsyncStream { $0.finish() } }
        func getSubscriptionStatus() async -> SubscriptionStatus { .inactive }
        func checkSubscriptionStatus() async throws -> SubscriptionStatus { .inactive }
        func loadOfferings() async throws -> SubscriptionOffering? { offering }
        func purchase(packageId: String) async throws -> SubscriptionStatus { .inactive }
        func purchase(packageId: String, inOffering offeringId: String) async throws -> SubscriptionStatus {
            purchasedFrom.append(offeringId)
            return .inactive
        }
        func restorePurchases() async throws -> SubscriptionStatus { .inactive }
        func syncUser(userId: String) async throws {}
        func clearUser() async throws {}
        func trackPaywallImpression(source: String, offeringId: String?) async {
            impressions.append(offeringId)
        }
    }

    func test_既定の実装はplacementにcurrentを返し_IDで買って記録する() async throws {
        let current = SubscriptionOffering(id: "default", packages: [])
        let useCase = SingleOffering(offering: current)

        let loaded = try await useCase.loadOffering(placement: "feature_gate")
        _ = try await useCase.purchase(packageId: "$rc_annual", from: try XCTUnwrap(loaded))
        await useCase.trackPaywallImpression(source: "gate", offering: try XCTUnwrap(loaded))

        XCTAssertEqual(loaded?.id, "default")
        XCTAssertEqual(loaded?.servedBy, .current)
        let purchasedFrom = await useCase.purchasedFrom
        let impressions = await useCase.impressions
        XCTAssertEqual(purchasedFrom, ["default"])
        XCTAssertEqual(impressions, ["default"])
    }

    // MARK: - Metadata

    func test_metadataは文字列だけを持ち_ほかの型の鍵を落としたと伝える() {
        let metadata = SubscriptionOffering.stringMetadata([
            "appeal": "see_progress",
            "onboarding_paywall": "off",
            "trial_days": 7,
            "enabled": false,
            "copy": ["ja": "見出し"],
        ])

        XCTAssertEqual(metadata.values, ["appeal": "see_progress", "onboarding_paywall": "off"])
        XCTAssertEqual(metadata.dropped, ["trial_days", "enabled", "copy"])
    }

    func test_手で作ったofferingはmetadataが空でcurrent() {
        let offering = SubscriptionOffering(id: "default", packages: [])
        XCTAssertEqual(offering.metadata, [:])
        XCTAssertEqual(offering.droppedMetadataKeys, [])
        XCTAssertEqual(offering.servedBy, .current)
    }
}
