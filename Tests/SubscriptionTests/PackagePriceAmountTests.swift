import Foundation
import XCTest
@testable import Subscription

final class PackagePriceAmountTests: XCTestCase {
    private func package(_ duration: PackageDuration, _ amount: Decimal, locale: Locale?) -> SubscriptionPackage {
        SubscriptionPackage(
            id: duration.rawValue, productId: duration.rawValue, title: "", description: "", price: "", pricePerMonth: nil,
            duration: duration, introductoryOffer: nil, priceAmount: amount, priceLocale: locale
        )
    }

    func testDerivedAmountIsFormattedInTheStorefrontCurrency() {
        let jp = Locale(identifier: "ja_JP")
        let annual = package(.annual, 6000, locale: jp)
        let monthly = package(.monthly, 800, locale: jp)
        let savings = monthly.priceAmount! * 12 - annual.priceAmount!
        XCTAssertEqual(annual.formattedPrice(savings), "¥3,600")
        XCTAssertEqual(package(.annual, 39.99, locale: Locale(identifier: "en_US")).formattedPrice(Decimal(string: "19.89")!), "$19.89")
    }

    func testNoLocaleMeansNoGuessedCurrency() {
        XCTAssertNil(package(.annual, 6000, locale: nil).formattedPrice(100))
    }

    func testDefaultsKeepExistingCallSitesUnchanged() {
        let p = SubscriptionPackage(id: "a", title: "", description: "", price: "¥6,000", pricePerMonth: nil, duration: .annual)
        XCTAssertNil(p.priceAmount)
        XCTAssertNil(p.priceLocale)
    }
}
