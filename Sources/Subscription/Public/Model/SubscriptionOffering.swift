import Foundation

/// How long one purchase lasts.
///
/// The raw values are stable identifiers meant for logging and analytics, not labels.
/// Switch over the case to build a label your app owns and localizes — a paywall is the
/// last place a package should be choosing wording on your behalf.
public enum PackageDuration: String, Sendable {
    case monthly
    case annual
    case lifetime

    /// A period this package does not model, such as weekly or a custom store duration.
    ///
    /// Reachable for products that are perfectly valid in the store, so treat it as a
    /// product to present rather than an error.
    case unknown
}

/// One purchasable product, with its price already formatted for display.
///
/// Every string here arrives localized and currency-formatted by the store for the
/// customer's storefront. Do not reformat them or assume a currency: the same product is
/// "¥6,000" for one customer and "$39.99" for another.
public struct SubscriptionPackage: Sendable, Identifiable {
    /// The identifier to pass to ``SubscriptionUseCase/purchase(packageId:)``.
    ///
    /// This is the package's identifier within the offering, not the App Store product
    /// identifier.
    public let id: String

    /// The App Store product identifier, such as `"pro.yearly"`.
    ///
    /// The identifier ``SubscriptionStatus/activePackageId`` reports once this package is bought,
    /// and the one to key the app's own copy and server data on: the package identifier is a
    /// dashboard setting (`$rc_annual` unless renamed) and can change without the product
    /// changing. Equal to ``id`` for a package made with the initialiser that does not take it.
    public let productId: String

    /// The product's display name as configured in the store.
    public let title: String

    /// The product's store description, which is often empty in practice because the field
    /// is optional in App Store Connect.
    public let description: String

    /// The price, already formatted in the customer's currency.
    public let price: String

    /// The monthly equivalent of an annual price, for a "works out at ¥500/month" line.
    ///
    /// `nil` for every package except an annual one. It is a derived figure and is never the
    /// amount charged.
    public let pricePerMonth: String?

    /// How long the purchase lasts.
    public let duration: PackageDuration

    /// The introductory offer on this product, such as a free trial, with whether this customer
    /// can still take it. `nil` when the product has none.
    ///
    /// Check ``IntroductoryOffer/eligibility`` before showing it: a customer who has used the
    /// offer before is charged ``price`` on day one.
    public let introductoryOffer: IntroductoryOffer?

    /// The price as a number, for arithmetic across packages such as "save ¥3,600 a year
    /// against paying monthly". `nil` when the package was made without one.
    ///
    /// Never show this directly: format a derived amount with ``formattedPrice(_:)`` so it
    /// reads in the same currency and style as ``price``.
    public let priceAmount: Decimal?

    /// The storefront locale the store formatted ``price`` in. `nil` when unknown.
    public let priceLocale: Locale?

    /// Formats an amount derived from ``priceAmount`` in this package's currency and storefront
    /// style, the way the store formats ``price``.
    ///
    /// Returns `nil` when the package does not know its storefront locale, rather than
    /// guessing a currency.
    public func formattedPrice(_ amount: Decimal) -> String? {
        guard let priceLocale else { return nil }
        return Self.currencyString(amount, locale: priceLocale)
    }

    static func currencyString(_ amount: Decimal, locale: Locale?) -> String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        return formatter.string(from: amount as NSDecimalNumber)
    }

    /// Creates a package.
    ///
    /// Provided for tests, previews, and paywall mock-ups; real values come from
    /// ``SubscriptionUseCase/loadOfferings()``. An `id` invented here cannot be purchased.
    ///
    /// - Parameters:
    ///   - id: The package identifier within its offering.
    ///   - title: The display name.
    ///   - description: The store description.
    ///   - price: The price, pre-formatted for the customer's storefront.
    ///   - pricePerMonth: The monthly equivalent for annual packages; `nil` otherwise.
    ///   - duration: How long the purchase lasts.
    ///   - introductoryOffer: The introductory offer, such as a free trial; `nil` for none.
    public init(
        id: String,
        title: String,
        description: String,
        price: String,
        pricePerMonth: String?,
        duration: PackageDuration,
        introductoryOffer: IntroductoryOffer? = nil
    ) {
        self.init(
            id: id,
            productId: id,
            title: title,
            description: description,
            price: price,
            pricePerMonth: pricePerMonth,
            duration: duration,
            introductoryOffer: introductoryOffer,
            priceAmount: nil,
            priceLocale: nil
        )
    }

    /// Creates a package whose App Store product identifier differs from its package identifier.
    ///
    /// - Parameters:
    ///   - id: The package identifier within its offering.
    ///   - productId: The App Store product identifier.
    ///   - title: The display name.
    ///   - description: The store description.
    ///   - price: The price, pre-formatted for the customer's storefront.
    ///   - pricePerMonth: The monthly equivalent for annual packages; `nil` otherwise.
    ///   - duration: How long the purchase lasts.
    ///   - introductoryOffer: The introductory offer, such as a free trial; `nil` for none.
    public init(
        id: String,
        productId: String,
        title: String,
        description: String,
        price: String,
        pricePerMonth: String?,
        duration: PackageDuration,
        introductoryOffer: IntroductoryOffer? = nil
    ) {
        self.init(
            id: id,
            productId: productId,
            title: title,
            description: description,
            price: price,
            pricePerMonth: pricePerMonth,
            duration: duration,
            introductoryOffer: introductoryOffer,
            priceAmount: nil,
            priceLocale: nil
        )
    }

    /// Creates a package that also knows its price as a number, for arithmetic across packages.
    ///
    /// - Parameters:
    ///   - id: The package identifier within its offering.
    ///   - productId: The App Store product identifier.
    ///   - title: The display name.
    ///   - description: The store description.
    ///   - price: The price, pre-formatted for the customer's storefront.
    ///   - pricePerMonth: The monthly equivalent for annual packages; `nil` otherwise.
    ///   - duration: How long the purchase lasts.
    ///   - introductoryOffer: The introductory offer, such as a free trial; `nil` for none.
    ///   - priceAmount: The price as a number.
    ///   - priceLocale: The storefront locale ``price`` is formatted in.
    public init(
        id: String,
        productId: String,
        title: String,
        description: String,
        price: String,
        pricePerMonth: String?,
        duration: PackageDuration,
        introductoryOffer: IntroductoryOffer?,
        priceAmount: Decimal?,
        priceLocale: Locale?
    ) {
        self.id = id
        self.productId = productId
        self.title = title
        self.description = description
        self.price = price
        self.pricePerMonth = pricePerMonth
        self.duration = duration
        self.introductoryOffer = introductoryOffer
        self.priceAmount = priceAmount
        self.priceLocale = priceLocale
    }
}

/// The set of products a paywall should show, as chosen in the RevenueCat dashboard.
///
/// Which offering is current is a server-side decision, so the products can change without
/// an app release. A paywall that needs a particular offering rather than the current one asks
/// for it by identifier with ``SubscriptionUseCase/loadOffering(id:)``, or for the one the
/// dashboard serves where the paywall opens with ``SubscriptionUseCase/loadOffering(placement:)``.
/// Build the paywall from whatever `packages` contains rather than assuming a fixed
/// monthly-and-annual pair.
public struct SubscriptionOffering: Sendable, Identifiable {
    /// How an offering was found: which question the dashboard answered with it.
    ///
    /// Buying from an offering and recording its impression go back to the store the same way,
    /// so a purchase made from a placement's offering carries that placement in RevenueCat.
    public enum ServedBy: Sendable, Equatable {
        /// The offering the dashboard marks current. Also what ``SubscriptionUseCase/loadOffering(placement:)``
        /// answers with when the dashboard serves nothing at the placement.
        case current
        /// Asked for by its identifier with ``SubscriptionUseCase/loadOffering(id:)``.
        case identifier
        /// Served at this placement by the dashboard's placements and targeting.
        case placement(String)
    }

    /// The offering's dashboard identifier, useful for attributing conversions to a paywall
    /// experiment.
    public let id: String

    /// The products to display, in the order the dashboard lists them.
    ///
    /// Can be empty if the offering has no products attached, which leaves a paywall with
    /// nothing to sell.
    public let packages: [SubscriptionPackage]

    /// The offering's metadata from the dashboard, keeping only the values that are strings.
    ///
    /// Metadata is a remote switch, so it is read as text the app compares against values it
    /// already knows, never as copy to show. A value of any other JSON type — a number, a
    /// boolean, an object — is left out rather than converted, and its key is listed in
    /// ``droppedMetadataKeys`` so the app can report a dashboard entry it cannot read.
    public let metadata: [String: String]

    /// The metadata keys whose values were not strings and are therefore missing from ``metadata``.
    public let droppedMetadataKeys: Set<String>

    /// How the offering was found.
    public let servedBy: ServedBy

    /// Creates an offering.
    ///
    /// Provided for tests and previews; real values come from
    /// ``SubscriptionUseCase/loadOfferings()``. The offering has no metadata and is reported as
    /// the current one.
    ///
    /// - Parameters:
    ///   - id: The offering's dashboard identifier.
    ///   - packages: The products to display.
    public init(id: String, packages: [SubscriptionPackage]) {
        self.init(id: id, packages: packages, metadata: [:], servedBy: .current)
    }

    /// Creates an offering with metadata, as the dashboard would return it.
    ///
    /// - Parameters:
    ///   - id: The offering's dashboard identifier.
    ///   - packages: The products to display.
    ///   - metadata: The string values of the offering's metadata.
    ///   - droppedMetadataKeys: The keys whose values were not strings.
    ///   - servedBy: How the offering was found.
    public init(
        id: String,
        packages: [SubscriptionPackage],
        metadata: [String: String],
        droppedMetadataKeys: Set<String> = [],
        servedBy: ServedBy
    ) {
        self.id = id
        self.packages = packages
        self.metadata = metadata
        self.droppedMetadataKeys = droppedMetadataKeys
        self.servedBy = servedBy
    }

    /// Splits the dashboard's metadata into its string values and the keys of everything else.
    static func stringMetadata(_ raw: [String: Any]) -> (values: [String: String], dropped: Set<String>) {
        var values: [String: String] = [:]
        var dropped: Set<String> = []
        for (key, value) in raw {
            if let text = value as? String {
                values[key] = text
            } else {
                dropped.insert(key)
            }
        }
        return (values, dropped)
    }
}
