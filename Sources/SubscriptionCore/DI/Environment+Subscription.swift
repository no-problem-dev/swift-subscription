import SwiftUI

/// The environment key backing `EnvironmentValues.subscriptionUseCase`.
///
/// Its default is `nil`, which is why the environment value is optional.
public struct SubscriptionUseCaseKey: EnvironmentKey {
    public static var defaultValue: SubscriptionUseCase? {
        nil
    }
}

public extension EnvironmentValues {
    /// The subscription use case, or `nil` when nothing injected one.
    ///
    /// `nil` means the view is running outside the injection point — a preview, or a screen
    /// reached before the modifier is applied. Treat it as "cannot sell anything here", not
    /// as "not subscribed", or a preview will render as an expired paywall.
    ///
    /// ```swift
    /// @Environment(\.subscriptionUseCase) private var subscriptionUseCase
    /// ```
    var subscriptionUseCase: SubscriptionUseCase? {
        get { self[SubscriptionUseCaseKey.self] }
        set { self[SubscriptionUseCaseKey.self] = newValue }
    }
}

/// Carries a ``SubscriptionUseCase`` into the environment across a package boundary.
///
/// Apply it with `View.subscriptionUseCase(_:)` rather than constructing it directly.
public struct SubscriptionUseCaseModifier: ViewModifier {
    private let subscriptionUseCase: SubscriptionUseCase

    /// Creates the modifier.
    ///
    /// - Parameter subscriptionUseCase: The instance to publish to descendant views.
    public init(subscriptionUseCase: SubscriptionUseCase) {
        self.subscriptionUseCase = subscriptionUseCase
    }

    public func body(content: Content) -> some View {
        content
            .environment(\.subscriptionUseCase, subscriptionUseCase)
    }
}

public extension View {
    /// Publishes a subscription use case to this view and its descendants.
    ///
    /// Apply it once, at the app's root, to the instance held for the process lifetime.
    /// Applying it to a view that SwiftUI re-creates reconfigures the store SDK on every
    /// rebuild.
    ///
    /// ```swift
    /// ContentView()
    ///     .subscriptionUseCase(subscriptionUseCase)
    /// ```
    ///
    /// - Parameter subscriptionUseCase: The instance descendants should resolve.
    /// - Returns: A view that publishes the instance to its descendants.
    func subscriptionUseCase(_ subscriptionUseCase: SubscriptionUseCase) -> some View {
        modifier(SubscriptionUseCaseModifier(subscriptionUseCase: subscriptionUseCase))
    }
}
