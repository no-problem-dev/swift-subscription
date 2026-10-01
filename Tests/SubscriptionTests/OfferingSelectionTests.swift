import XCTest
@testable import Subscription

/// Covers choosing an offering by identifier: the use case passes the identifier through to the
/// store, and the protocol's default implementation, for a conformance that knows one offering,
/// never sells the current offering in place of the one asked for.
final class OfferingSelectionTests: XCTestCase {
    private static let annual = SubscriptionPackage(
        id: "$rc_annual", title: "", description: "", price: "¥6,000", pricePerMonth: "¥500", duration: .annual
    )

    // MARK: - SubscriptionUseCaseImpl

    func test_IDを指定したofferingの読み込みはそのIDでストアに聞く() async throws {
        let mock = SubscriptionRepositoryMock()
        await mock.setOffering(SubscriptionOffering(id: "trip", packages: [Self.annual]))
        let useCase = SubscriptionUseCaseImpl(repository: mock)

        _ = try await useCase.loadOffering(id: "trip")
        _ = try await useCase.loadOfferings()

        let asked = await mock.loadedOfferingIds
        XCTAssertEqual(asked, ["trip", nil])
    }

    func test_IDを指定したofferingから買うとそのIDで買う() async throws {
        let mock = SubscriptionRepositoryMock()
        let useCase = SubscriptionUseCaseImpl(repository: mock)

        _ = try await useCase.purchase(packageId: "$rc_annual", inOffering: "trip")
        _ = try await useCase.purchase(packageId: "$rc_annual")

        let purchasedFrom = await mock.purchasedFrom
        XCTAssertEqual(purchasedFrom, ["trip", nil])
    }

    // MARK: - Default implementation

    /// A conformance that knows one offering and implements neither of the new calls, as the
    /// apps' stand-ins do.
    private struct SingleOffering: SubscriptionUseCase {
        let offering: SubscriptionOffering?

        func observeSubscriptionStatus() -> AsyncStream<SubscriptionStatus> { AsyncStream { $0.finish() } }
        func getSubscriptionStatus() async -> SubscriptionStatus { .inactive }
        func checkSubscriptionStatus() async throws -> SubscriptionStatus { .inactive }
        func loadOfferings() async throws -> SubscriptionOffering? { offering }
        func purchase(packageId: String) async throws -> SubscriptionStatus {
            SubscriptionStatus(isActive: true, activePackageId: packageId)
        }
        func restorePurchases() async throws -> SubscriptionStatus { .inactive }
        func syncUser(userId: String) async throws {}
        func clearUser() async throws {}
    }

    func test_既定の実装は現在のofferingのIDなら見つける() async throws {
        let useCase = SingleOffering(offering: SubscriptionOffering(id: "default", packages: [Self.annual]))

        let found = try await useCase.loadOffering(id: "default")

        XCTAssertEqual(found?.id, "default")
    }

    func test_既定の実装は別のIDに現在のofferingを返さない() async throws {
        let useCase = SingleOffering(offering: SubscriptionOffering(id: "default", packages: [Self.annual]))

        let found = try await useCase.loadOffering(id: "trip")

        XCTAssertNil(found)
    }

    func test_既定の実装は無いofferingから買おうとするとpackageNotFound() async {
        let useCase = SingleOffering(offering: SubscriptionOffering(id: "default", packages: [Self.annual]))

        do {
            _ = try await useCase.purchase(packageId: "$rc_annual", inOffering: "trip")
            XCTFail("expected packageNotFound")
        } catch SubscriptionError.packageNotFound(let id) {
            XCTAssertEqual(id, "$rc_annual")
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func test_既定の実装は現在のofferingのパッケージなら買う() async throws {
        let useCase = SingleOffering(offering: SubscriptionOffering(id: "default", packages: [Self.annual]))

        let status = try await useCase.purchase(packageId: "$rc_annual", inOffering: "default")

        XCTAssertTrue(status.isActive)
    }
}

final class SubscriptionPackageProductIdTests: XCTestCase {
    func testProductIdDefaultsToThePackageIdentifier() {
        let package = SubscriptionPackage(id: "pro.yearly", title: "", description: "", price: "¥6,000", pricePerMonth: nil, duration: .annual)
        XCTAssertEqual(package.productId, "pro.yearly")
    }

    func testProductIdCanDifferFromThePackageIdentifier() {
        let package = SubscriptionPackage(
            id: "$rc_annual", productId: "pro.yearly", title: "", description: "", price: "¥6,000", pricePerMonth: nil, duration: .annual
        )
        XCTAssertEqual(package.id, "$rc_annual")
        XCTAssertEqual(package.productId, "pro.yearly")
    }
}
