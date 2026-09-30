import Foundation
import Subscription

/// The words on a paywall that this package puts there, so an app can localize them.
///
/// **No price is in here, and none can be.** Every amount a paywall shows comes from a
/// `SubscriptionPackage`, which the store formatted for the customer's storefront. That is
/// what keeps the billed amount the billed amount: there is no field through which an app can
/// substitute its own figure for the store's, and no field through which the monthly
/// equivalent of an annual price can become the headline.
///
/// The defaults are English. Pass your own for anything else — these strings are not
/// localized by this package, because a package cannot know which languages the app ships.
public struct PaywallLabels: Sendable {
    /// The verb on the purchase button.
    ///
    /// A verb, not an offer. Putting an amount here ("Start for ¥500/month") is the App Store
    /// Review 3.1.2(c) rejection this type exists to make hard: the row above already shows
    /// what is actually charged, and a second, smaller number contradicting it is exactly what
    /// gets flagged.
    public var purchase: String

    /// The restore button. Required on a paywall that sells a non-consumable or a subscription.
    public var restore: String

    /// The terms-of-use link.
    public var terms: String

    /// The privacy-policy link.
    public var privacy: String

    /// What follows the monthly equivalent of an annual price, as in "¥500 / month".
    ///
    /// Only ever attached to `SubscriptionPackage.pricePerMonth`, and only in the secondary
    /// line of a plan row.
    public var perMonthSuffix: String

    /// The badge on the plan the paywall recommends.
    public var recommendedBadge: String

    /// The line under a plan that starts with a free trial, from the trial's length, as in
    /// "7-day free trial".
    ///
    /// Shown only when the customer is eligible for the trial
    /// (`IntroductoryOffer.isEligibleFreeTrial`). Someone who has used it before is charged on
    /// day one, and this line would be a promise the store does not keep.
    public var freeTrial: @Sendable (IntroductoryOffer.Period) -> String

    /// Creates a set of labels.
    ///
    /// - Parameters:
    ///   - purchase: The verb on the purchase button.
    ///   - restore: The restore button.
    ///   - terms: The terms-of-use link.
    ///   - privacy: The privacy-policy link.
    ///   - perMonthSuffix: What follows a monthly equivalent.
    ///   - recommendedBadge: The badge on the recommended plan.
    ///   - freeTrial: The line under a plan that starts with a free trial.
    public init(
        purchase: String = "Continue",
        restore: String = "Restore Purchases",
        terms: String = "Terms of Use",
        privacy: String = "Privacy Policy",
        perMonthSuffix: String = "/ month",
        recommendedBadge: String = "Best value",
        freeTrial: @escaping @Sendable (IntroductoryOffer.Period) -> String = PaywallLabels.englishFreeTrial
    ) {
        self.purchase = purchase
        self.restore = restore
        self.terms = terms
        self.privacy = privacy
        self.perMonthSuffix = perMonthSuffix
        self.recommendedBadge = recommendedBadge
        self.freeTrial = freeTrial
    }

    /// The labels in Japanese.
    public static let japanese = PaywallLabels(
        purchase: "続ける",
        restore: "購入を復元",
        terms: "利用規約",
        privacy: "プライバシーポリシー",
        perMonthSuffix: "/ 月",
        recommendedBadge: "おすすめ",
        freeTrial: japaneseFreeTrial
    )

    /// "7-day free trial", "1-month free trial".
    public static let englishFreeTrial: @Sendable (IntroductoryOffer.Period) -> String = { period in
        let unit = switch period.unit {
        case .day: "day"
        case .week: "week"
        case .month: "month"
        case .year: "year"
        }
        return "\(period.value)-\(unit) free trial"
    }

    /// 「7日間無料」「1か月無料」。
    public static let japaneseFreeTrial: @Sendable (IntroductoryOffer.Period) -> String = { period in
        let unit = switch period.unit {
        case .day: "日間"
        case .week: "週間"
        case .month: "か月"
        case .year: "年間"
        }
        return "\(period.value)\(unit)無料"
    }
}
