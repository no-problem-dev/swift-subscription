import Foundation

/// A value the app hands to a paywall designed in the RevenueCat dashboard, shown where the
/// paywall's text says `{{ custom.name }}` and usable in its display rules.
///
/// The dashboard declares each variable with a default; a variable the app does not pass shows
/// that default. Values are the app's own type so that holding them needs neither RevenueCat nor
/// RevenueCatUI. `SubscriptionRevenueCatUI` turns them into RevenueCat's.
///
/// ```swift
/// PaywallContainer(
///     mode: .automatic,
///     variables: ["headline": .string(headline), "trial_days": .number(7)]
/// ) { handlers in … }
/// ```
///
/// Names start with a letter and hold letters, digits and underscores; RevenueCatUI drops any
/// other name.
public enum PaywallVariable: Sendable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
}

extension PaywallVariable: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}
