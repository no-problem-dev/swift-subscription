import RevenueCat
import XCTest
@testable import Subscription

/// Covers the pure core of `RevenueCatRepository`: the entitlement decision, the monthly
/// price conversion, and the package-type mapping. Never contacts the RevenueCat SDK.
final class RevenueCatRepositoryTests: XCTestCase {
    // MARK: - Entitlement decision

    func test_有効なエンタイトルメントがあればアクティブなステータスを返す() {
        let expiration = Date(timeIntervalSince1970: 1_900_000_000)
        let entitlements = [
            "premium": RevenueCatRepository.EntitlementSnapshot(
                isActive: true,
                productIdentifier: "com.example.annual",
                expirationDate: expiration
            )
        ]

        let status = RevenueCatRepository.subscriptionStatus(from: entitlements, entitlementId: "premium")

        XCTAssertEqual(
            status,
            SubscriptionStatus(
                isActive: true,
                activeEntitlementId: "premium",
                activePackageId: "com.example.annual",
                expirationDate: expiration
            )
        )
    }

    func test_エンタイトルメントが空ならinactive() {
        let status = RevenueCatRepository.subscriptionStatus(from: [:], entitlementId: "premium")

        XCTAssertEqual(status, .inactive)
    }

    func test_エンタイトルメントが失効していればinactive() {
        let entitlements = [
            "premium": RevenueCatRepository.EntitlementSnapshot(
                isActive: false,
                productIdentifier: "com.example.annual",
                expirationDate: Date(timeIntervalSince1970: 1_000)
            )
        ]

        let status = RevenueCatRepository.subscriptionStatus(from: entitlements, entitlementId: "premium")

        XCTAssertEqual(status, .inactive)
    }

    func test_別IDのエンタイトルメントが有効でも対象IDが無ければinactive() {
        let entitlements = [
            "pro": RevenueCatRepository.EntitlementSnapshot(
                isActive: true,
                productIdentifier: "com.example.pro",
                expirationDate: nil
            )
        ]

        let status = RevenueCatRepository.subscriptionStatus(from: entitlements, entitlementId: "premium")

        XCTAssertEqual(status, .inactive)
    }

    func test_買い切りエンタイトルメントは有効期限なしでもアクティブ() {
        let entitlements = [
            "premium": RevenueCatRepository.EntitlementSnapshot(
                isActive: true,
                productIdentifier: "com.example.lifetime",
                expirationDate: nil
            )
        ]

        let status = RevenueCatRepository.subscriptionStatus(from: entitlements, entitlementId: "premium")

        XCTAssertTrue(status.isActive)
        XCTAssertEqual(status.activePackageId, "com.example.lifetime")
        XCTAssertNil(status.expirationDate)
    }

    // MARK: - Annual to monthly conversion

    func test_年額パッケージは12分の1の月額換算文字列を返す() {
        let result = RevenueCatRepository.monthlyPriceString(
            packageType: .annual,
            price: 60,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(result, "$5.00")
    }

    func test_月額換算は割り切れない価格も通貨書式で丸める() {
        let result = RevenueCatRepository.monthlyPriceString(
            packageType: .annual,
            price: Decimal(string: "59.88")!,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(result, "$4.99")
    }

    func test_月額換算は日本円ロケールの通貨書式に従う() throws {
        let result = RevenueCatRepository.monthlyPriceString(
            packageType: .annual,
            price: 6000,
            locale: Locale(identifier: "ja_JP")
        )

        let unwrapped = try XCTUnwrap(result)
        XCTAssertTrue(unwrapped.contains("500"), "月額換算 6000/12=500 が含まれること: \(unwrapped)")
        XCTAssertFalse(unwrapped.contains("6000"), "年額のままの値が出ないこと: \(unwrapped)")
    }

    func test_年額以外のパッケージは月額換算しない() {
        let locale = Locale(identifier: "en_US")

        XCTAssertNil(RevenueCatRepository.monthlyPriceString(packageType: .monthly, price: 5, locale: locale))
        XCTAssertNil(RevenueCatRepository.monthlyPriceString(packageType: .lifetime, price: 100, locale: locale))
        XCTAssertNil(RevenueCatRepository.monthlyPriceString(packageType: .weekly, price: 2, locale: locale))
    }

    // MARK: - Package duration mapping

    func test_パッケージ種別を課金期間に変換する() {
        XCTAssertEqual(RevenueCatRepository.packageDuration(for: .monthly), .monthly)
        XCTAssertEqual(RevenueCatRepository.packageDuration(for: .annual), .annual)
        XCTAssertEqual(RevenueCatRepository.packageDuration(for: .lifetime), .lifetime)
        XCTAssertEqual(RevenueCatRepository.packageDuration(for: .weekly), .unknown)
        XCTAssertEqual(RevenueCatRepository.packageDuration(for: .unknown), .unknown)
    }
}
