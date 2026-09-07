import Foundation

/// The settings ``SubscriptionUseCaseImpl`` needs before it can talk to the store.
///
/// ## Example
/// ```swift
/// let config = SubscriptionConfiguration(
///     apiKey: "your_revenuecat_api_key",
///     entitlementId: "premium"
/// )
/// ```
public struct SubscriptionConfiguration: Sendable {
    /// How long a cached entitlement outlives its expiration date when the store cannot be
    /// reached: three days.
    ///
    /// Short on purpose. The grace covers a renewal this device has not been online to see,
    /// which is a matter of hours; every day beyond that is a day a lapsed subscription keeps
    /// working. Lengthen it for an app that is genuinely used away from signal.
    public static let defaultGracePeriod: TimeInterval = 3 * 24 * 60 * 60

    /// The RevenueCat public SDK key for this platform.
    ///
    /// Use the platform's public key, not a secret key: this value ships inside the app and
    /// is readable by anyone who inspects the binary. An empty string is accepted here and
    /// surfaces later as ``SubscriptionError/notConfigured`` from every store call.
    public let apiKey: String

    /// The entitlement whose active state means "subscribed".
    ///
    /// Must match the entitlement identifier in the RevenueCat dashboard exactly. A typo does
    /// not fail loudly; it makes every paying customer look unsubscribed, because no
    /// entitlement by that name is ever active.
    public let entitlementId: String

    /// How long a cached entitlement stays honoured past its expiration date while the store
    /// cannot be reached.
    ///
    /// Applies only to readings replayed from the ``EntitlementCache`` at launch. A reading the
    /// store answered is used exactly as the store gave it, because the store runs a grace
    /// period of its own and reports an active entitlement with a date already past during it.
    ///
    /// A lifetime purchase has no expiration date and is never affected by this.
    public let gracePeriod: TimeInterval

    /// A hook to attach your own attributes to the billing profile after sign-in.
    ///
    /// Runs on every ``SubscriptionUseCase/syncUser(userId:)`` after the identity swap
    /// succeeds, and sign-in waits on it. Keep it short, and do not put anything the store
    /// should not hold into it.
    public let customAttributesSetter: (@Sendable (String) async -> Void)?

    /// Creates a configuration.
    ///
    /// - Parameters:
    ///   - apiKey: The RevenueCat public SDK key for this platform.
    ///   - entitlementId: The entitlement that counts as subscribed. Defaults to `"premium"`,
    ///     which is only correct if the dashboard uses that exact name.
    ///   - gracePeriod: How long a cached entitlement outlives its expiration date while the
    ///     store is unreachable. Defaults to ``defaultGracePeriod``.
    ///   - customAttributesSetter: An optional hook run after sign-in.
    public init(
        apiKey: String,
        entitlementId: String = "premium",
        gracePeriod: TimeInterval = SubscriptionConfiguration.defaultGracePeriod,
        customAttributesSetter: (@Sendable (String) async -> Void)? = nil
    ) {
        self.apiKey = apiKey
        self.entitlementId = entitlementId
        self.gracePeriod = gracePeriod
        self.customAttributesSetter = customAttributesSetter
    }
}
