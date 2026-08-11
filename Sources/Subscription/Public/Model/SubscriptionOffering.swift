import Foundation

/// How long one purchase lasts.
///
/// - Warning: The raw values are hard-coded Japanese display strings, as the declarations
///   below show. Rendering `rawValue` puts Japanese on the paywall regardless of the device
///   language. Switch over the case and supply your own localized label.
public enum PackageDuration: String, Sendable {
    case monthly = "月額"
    case annual = "年額"
    case lifetime = "買い切り"

    /// A period this package does not model, such as weekly or a custom store duration.
    ///
    /// Reachable for products that are perfectly valid in the store, so treat it as a
    /// product to present rather than an error. Its raw value is the empty string.
    case unknown = ""
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
    public init(
        id: String,
        title: String,
        description: String,
        price: String,
        pricePerMonth: String?,
        duration: PackageDuration
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.price = price
        self.pricePerMonth = pricePerMonth
        self.duration = duration
    }
}

/// The set of products a paywall should show, as chosen in the RevenueCat dashboard.
///
/// Which offering is current is a server-side decision, so the products can change without
/// an app release. Build the paywall from whatever `packages` contains rather than assuming
/// a fixed monthly-and-annual pair.
public struct SubscriptionOffering: Sendable, Identifiable {
    /// The offering's dashboard identifier, useful for attributing conversions to a paywall
    /// experiment.
    public let id: String

    /// The products to display, in the order the dashboard lists them.
    ///
    /// Can be empty if the offering has no products attached, which leaves a paywall with
    /// nothing to sell.
    public let packages: [SubscriptionPackage]

    /// Creates an offering.
    ///
    /// Provided for tests and previews; real values come from
    /// ``SubscriptionUseCase/loadOfferings()``.
    ///
    /// - Parameters:
    ///   - id: The offering's dashboard identifier.
    ///   - packages: The products to display.
    public init(id: String, packages: [SubscriptionPackage]) {
        self.id = id
        self.packages = packages
    }
}
