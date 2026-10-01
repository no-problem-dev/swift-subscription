import RevenueCatUI
import SubscriptionUI
import SwiftUI

extension View {
    /// Hands custom variables to every RevenueCat paywall below this view.
    ///
    /// An environment value, so it reaches a ``RevenueCatPaywallView`` or a ``PaywallContainer``
    /// from any ancestor. ``PaywallContainer/init(mode:variables:onEntitled:onError:onDismiss:onPending:onNothingToRestore:custom:)``
    /// applies it for you.
    ///
    /// - Parameter variables: The values by the name the dashboard gives them, without the
    ///   `custom.` prefix.
    public func paywallVariables(_ variables: [String: PaywallVariable]) -> some View {
        customPaywallVariables(variables.mapValues(\.revenueCatValue))
    }
}

extension PaywallVariable {
    var revenueCatValue: CustomVariableValue {
        switch self {
        case .string(let value): .string(value)
        case .number(let value): .number(value)
        case .bool(let value): .bool(value)
        }
    }
}
