import RevenueCat
import XCTest
@testable import Subscription

/// Covers the introductory offer a paywall reads: how long it lasts, when the regular price is
/// first charged, and the store's answers mapped onto the package's own types.
final class IntroductoryOfferTests: XCTestCase {
    private static let tokyo: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        tokyo.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private static func trial(_ eligibility: IntroductoryOffer.Eligibility) -> IntroductoryOffer {
        IntroductoryOffer(
            paymentMode: .freeTrial,
            period: IntroductoryOffer.Period(value: 7, unit: .day),
            price: "¥0",
            eligibility: eligibility
        )
    }

    // MARK: - Reading the offer

    func test_7日間の無料トライアルは7日後に通常の額を請求する() {
        let billed = Self.trial(.eligible).regularBillingDate(from: Self.date(2026, 9, 10), in: Self.tokyo)

        XCTAssertEqual(billed, Self.date(2026, 9, 17))
    }

    func test_期間の長さは1期間と回数の積() {
        let offer = IntroductoryOffer(
            paymentMode: .payAsYouGo,
            period: IntroductoryOffer.Period(value: 1, unit: .month),
            periodCount: 3,
            price: "¥100",
            eligibility: .eligible
        )

        XCTAssertEqual(offer.duration, IntroductoryOffer.Period(value: 3, unit: .month))
        XCTAssertEqual(offer.regularBillingDate(from: Self.date(2026, 1, 31), in: Self.tokyo), Self.date(2026, 4, 30))
    }

    func test_週は7日として数える() {
        let end = IntroductoryOffer.Period(value: 2, unit: .week).end(from: Self.date(2026, 9, 1), in: Self.tokyo)

        XCTAssertEqual(end, Self.date(2026, 9, 15))
    }

    func test_無料トライアルを出してよいのは対象の人だけ() {
        XCTAssertTrue(Self.trial(.eligible).isEligibleFreeTrial)
        XCTAssertFalse(Self.trial(.ineligible).isEligibleFreeTrial)
        XCTAssertFalse(Self.trial(.unknown).isEligibleFreeTrial)
    }

    func test_有料の導入価格は無料トライアルではない() {
        let offer = IntroductoryOffer(
            paymentMode: .payUpFront,
            period: IntroductoryOffer.Period(value: 1, unit: .year),
            price: "¥3,000",
            eligibility: .eligible
        )

        XCTAssertFalse(offer.isEligibleFreeTrial)
    }

    func test_導入オファーを指定しないパッケージは導入オファーを持たない() {
        let package = SubscriptionPackage(
            id: "monthly", title: "", description: "", price: "¥980", pricePerMonth: nil, duration: .monthly
        )

        XCTAssertNil(package.introductoryOffer)
    }

    // MARK: - Mapping the store's answers

    func test_ストアが対象と答えたときだけeligible() {
        XCTAssertEqual(RevenueCatRepository.introductoryEligibility(.eligible), .eligible)
        XCTAssertEqual(RevenueCatRepository.introductoryEligibility(.ineligible), .ineligible)
        XCTAssertEqual(RevenueCatRepository.introductoryEligibility(.noIntroOfferExists), .ineligible)
        XCTAssertEqual(RevenueCatRepository.introductoryEligibility(.unknown), .unknown)
        XCTAssertEqual(RevenueCatRepository.introductoryEligibility(nil), .unknown)
    }

    func test_支払い方と期間の単位をそのまま写す() {
        XCTAssertEqual(RevenueCatRepository.introductoryPaymentMode(.freeTrial), .freeTrial)
        XCTAssertEqual(RevenueCatRepository.introductoryPaymentMode(.payAsYouGo), .payAsYouGo)
        XCTAssertEqual(RevenueCatRepository.introductoryPaymentMode(.payUpFront), .payUpFront)
        XCTAssertEqual(RevenueCatRepository.periodUnit(.day), .day)
        XCTAssertEqual(RevenueCatRepository.periodUnit(.week), .week)
        XCTAssertEqual(RevenueCatRepository.periodUnit(.month), .month)
        XCTAssertEqual(RevenueCatRepository.periodUnit(.year), .year)
    }

    // MARK: - Pending purchases

    func test_承認待ちの購入は失敗でなくpurchasePending() {
        let error = RevenueCatRepository.purchaseError(ErrorCode.paymentPendingError)

        guard case .purchasePending = error else {
            return XCTFail("expected .purchasePending, got \(error)")
        }
    }

    func test_ほかの購入エラーはpurchaseFailed() {
        let error = RevenueCatRepository.purchaseError(ErrorCode.storeProblemError)

        guard case .purchaseFailed = error else {
            return XCTFail("expected .purchaseFailed, got \(error)")
        }
    }
}
