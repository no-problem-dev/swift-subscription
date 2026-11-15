import Foundation
import XCTest
@testable import SubscriptionCore

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

    func testStorefrontLocaleKeepsTheProductCurrencyOnAnotherLanguageDevice() throws {
        let korean = Locale(identifier: "ko_KR")
        let locale = try XCTUnwrap(SubscriptionPackage.storefrontLocale(korean, currencyCode: "USD"))
        let annual = package(.annual, Decimal(string: "9.99")!, locale: locale)
        let perMonth = try XCTUnwrap(annual.formattedPrice(annual.priceAmount! / 12))
        XCTAssertFalse(perMonth.contains("₩"), perMonth)
        XCTAssertTrue(perMonth.contains("0.83"), perMonth)
    }

    func testStorefrontLocaleWithoutACurrencyCodeIsTheLocale() {
        let jp = Locale(identifier: "ja_JP")
        XCTAssertEqual(SubscriptionPackage.storefrontLocale(jp, currencyCode: nil), jp)
        XCTAssertNil(SubscriptionPackage.storefrontLocale(nil, currencyCode: "USD"))
    }

    func testStorefrontLocaleKeepsTheCustomerDigits() throws {
        let arabic = Locale(identifier: "ar_SA@numbers=latn")
        let locale = try XCTUnwrap(SubscriptionPackage.storefrontLocale(arabic, currencyCode: "USD"))
        let text = try XCTUnwrap(package(.annual, 60, locale: locale).formattedPrice(5))
        XCTAssertTrue(text.contains("5"), text)
        XCTAssertFalse(text.contains("ر.س"), text)
    }
}
