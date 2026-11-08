import Foundation

/// The introductory offer on a subscription — most often a free trial — and whether this
/// customer can still take it.
///
/// The App Store lets each customer take an introductory offer once per subscription group.
/// Someone who has already used it is charged the full price on day one, so a paywall that
/// shows "7 days free" to them is promising something the store will not give. Show the offer
/// only when ``eligibility`` is ``Eligibility/eligible``; for anything else, show the price as
/// what is charged today.
public struct IntroductoryOffer: Sendable, Hashable {
    /// How the introductory price is charged.
    public enum PaymentMode: String, Sendable, Hashable {
        /// Nothing is charged for the offer's duration. ``IntroductoryOffer/price`` is zero.
        case freeTrial
        /// ``IntroductoryOffer/price`` is charged once per period, ``IntroductoryOffer/periodCount``
        /// times.
        case payAsYouGo
        /// ``IntroductoryOffer/price`` is charged once, up front, for the whole duration.
        case payUpFront
    }

    /// Whether the store will give this customer the offer.
    public enum Eligibility: String, Sendable, Hashable {
        /// The customer has not used an introductory offer in this subscription group.
        case eligible
        /// The customer has already used one; the full price is charged from the start.
        case ineligible
        /// The store could not say. Treat it as ``ineligible``: promising a trial the store then
        /// declines to give is the worse of the two mistakes.
        case unknown
    }

    /// A length of time in calendar units, as the store expresses subscription periods.
    public struct Period: Sendable, Hashable {
        /// The calendar unit a period is counted in.
        public enum Unit: String, Sendable, Hashable {
            case day
            case week
            case month
            case year
        }

        /// How many units.
        public let value: Int

        /// Which unit.
        public let unit: Unit

        /// Creates a period.
        ///
        /// - Parameters:
        ///   - value: How many units.
        ///   - unit: Which unit.
        public init(value: Int, unit: Unit) {
            self.value = value
            self.unit = unit
        }

        /// The date this period ends when it starts at `start`, counted in `calendar`.
        ///
        /// Counted in calendar units rather than seconds, so a one-month period starting on
        /// 31 January ends when the calendar says, not after a fixed number of days.
        public func end(from start: Date, in calendar: Calendar = .current) -> Date? {
            let component: Calendar.Component
            let amount: Int
            switch unit {
            case .day: (component, amount) = (.day, value)
            case .week: (component, amount) = (.day, value * 7)
            case .month: (component, amount) = (.month, value)
            case .year: (component, amount) = (.year, value)
            }
            return calendar.date(byAdding: component, value: amount, to: start)
        }
    }

    /// How the introductory price is charged.
    public let paymentMode: PaymentMode

    /// One period of the offer. For a free trial this is the trial's length.
    public let period: Period

    /// How many periods the offer lasts. `1` for a free trial and for a pay-up-front offer.
    public let periodCount: Int

    /// The introductory price for one period, already formatted for the customer's storefront.
    public let price: String

    /// Whether this customer can take the offer.
    public let eligibility: Eligibility

    /// Creates an offer.
    ///
    /// Provided for tests and previews; real values come from
    /// ``SubscriptionUseCase/loadOfferings()``.
    ///
    /// - Parameters:
    ///   - paymentMode: How the introductory price is charged.
    ///   - period: One period of the offer.
    ///   - periodCount: How many periods the offer lasts.
    ///   - price: The introductory price for one period, pre-formatted.
    ///   - eligibility: Whether this customer can take the offer.
    public init(
        paymentMode: PaymentMode,
        period: Period,
        periodCount: Int = 1,
        price: String,
        eligibility: Eligibility
    ) {
        self.paymentMode = paymentMode
        self.period = period
        self.periodCount = periodCount
        self.price = price
        self.eligibility = eligibility
    }

    /// The whole length of the offer: ``period`` times ``periodCount``.
    ///
    /// The regular price is first charged when this has passed.
    public var duration: Period {
        Period(value: period.value * periodCount, unit: period.unit)
    }

    /// Whether this is a free trial the customer can take — the one question a paywall asks
    /// before writing "7 days free".
    public var isEligibleFreeTrial: Bool {
        paymentMode == .freeTrial && eligibility == .eligible
    }

    /// The date the regular price is first charged, for an offer taken at `start`.
    ///
    /// The date to put on a paywall's "then ¥6,000 on 17 September" line and on the reminder
    /// before the trial ends.
    public func regularBillingDate(from start: Date, in calendar: Calendar = .current) -> Date? {
        duration.end(from: start, in: calendar)
    }
}
