import Foundation

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

    /// Creates a set of labels.
    ///
    /// - Parameters:
    ///   - purchase: The verb on the purchase button.
    ///   - restore: The restore button.
    ///   - terms: The terms-of-use link.
    ///   - privacy: The privacy-policy link.
    ///   - perMonthSuffix: What follows a monthly equivalent.
    ///   - recommendedBadge: The badge on the recommended plan.
    public init(
        purchase: String = "Continue",
        restore: String = "Restore Purchases",
        terms: String = "Terms of Use",
        privacy: String = "Privacy Policy",
        perMonthSuffix: String = "/ month",
        recommendedBadge: String = "Best value"
    ) {
        self.purchase = purchase
        self.restore = restore
        self.terms = terms
        self.privacy = privacy
        self.perMonthSuffix = perMonthSuffix
        self.recommendedBadge = recommendedBadge
    }
}
