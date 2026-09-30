import Subscription
import XCTest
@testable import SubscriptionUI

/// Covers the words a paywall puts under a plan that starts with a free trial.
final class PaywallLabelsTests: XCTestCase {
    func test_英語の無料トライアルの行() {
        let labels = PaywallLabels()

        XCTAssertEqual(labels.freeTrial(IntroductoryOffer.Period(value: 7, unit: .day)), "7-day free trial")
        XCTAssertEqual(labels.freeTrial(IntroductoryOffer.Period(value: 1, unit: .month)), "1-month free trial")
    }

    func test_日本語の無料トライアルの行() {
        let labels = PaywallLabels.japanese

        XCTAssertEqual(labels.freeTrial(IntroductoryOffer.Period(value: 7, unit: .day)), "7日間無料")
        XCTAssertEqual(labels.freeTrial(IntroductoryOffer.Period(value: 2, unit: .week)), "2週間無料")
        XCTAssertEqual(labels.freeTrial(IntroductoryOffer.Period(value: 1, unit: .month)), "1か月無料")
        XCTAssertEqual(labels.freeTrial(IntroductoryOffer.Period(value: 1, unit: .year)), "1年間無料")
    }

    func test_日本語の文言() {
        let labels = PaywallLabels.japanese

        XCTAssertEqual(labels.restore, "購入を復元")
        XCTAssertEqual(labels.terms, "利用規約")
        XCTAssertEqual(labels.privacy, "プライバシーポリシー")
    }
}
