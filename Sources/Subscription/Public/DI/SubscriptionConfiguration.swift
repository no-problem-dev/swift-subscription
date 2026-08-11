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
    ///   - customAttributesSetter: An optional hook run after sign-in.
    public init(
        apiKey: String,
        entitlementId: String = "premium",
        customAttributesSetter: (@Sendable (String) async -> Void)? = nil
    ) {
        self.apiKey = apiKey
        self.entitlementId = entitlementId
        self.customAttributesSetter = customAttributesSetter
    }
}
