import Foundation

/// The three things a paywall reports, whichever paywall it is.
///
/// `PaywallContainer` hands one of these to the closure that builds the app's own paywall, and
/// wires the RevenueCat paywall to the same three. Pass them through to ``PaywallView`` and to
/// the close button, and the app hears about a purchase, a failure or a dismissal in the same
/// place whichever paywall the customer saw.
///
/// ```swift
/// PaywallContainer(mode: .automatic, onEntitled: { … }) { handlers in
///     NavigationStack {
///         PaywallView(
///             pages: pages,
///             links: links,
///             onEntitled: handlers.onEntitled,
///             onError: handlers.onError
///         )
///         .toolbar {
///             ToolbarItem(placement: .cancellationAction) {
///                 Button("Close", action: handlers.onDismiss)
///             }
///         }
///     }
/// }
/// ```
public struct PaywallHandlers {
    /// Call when a purchase or a restore leaves the customer entitled.
    public let onEntitled: @MainActor () -> Void

    /// Call when a purchase or a restore fails.
    ///
    /// Not for a cancelled purchase: dismissing the store's sheet is an ordinary outcome, and
    /// ``PaywallView`` does not report it either.
    public let onError: @MainActor (any Error) -> Void

    /// Call when the customer asks to close the paywall without buying.
    public let onDismiss: @MainActor () -> Void

    /// Creates a set of handlers.
    ///
    /// - Parameters:
    ///   - onEntitled: Run when a purchase or a restore leaves the customer entitled.
    ///   - onError: Run when a purchase or a restore fails.
    ///   - onDismiss: Run when the customer asks to close the paywall.
    public init(
        onEntitled: @escaping @MainActor () -> Void,
        onError: @escaping @MainActor (any Error) -> Void,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        self.onEntitled = onEntitled
        self.onError = onError
        self.onDismiss = onDismiss
    }
}
