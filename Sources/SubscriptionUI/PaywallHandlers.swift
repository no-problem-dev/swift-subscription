import Foundation

/// What a paywall reports, whichever paywall it is, and which offering it was asked to sell.
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
///             offering: handlers.offeringIdentifier,
///             onEntitled: handlers.onEntitled,
///             onError: handlers.onError,
///             onPending: handlers.onPending,
///             onNothingToRestore: handlers.onNothingToRestore
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

    /// Call when a purchase is waiting for approval (Ask to Buy). `nil` when the app did not
    /// ask to hear about it.
    public let onPending: (@MainActor () -> Void)?

    /// Call when a restore succeeds but finds nothing that entitles the customer. `nil` when
    /// the app did not ask to hear about it.
    public let onNothingToRestore: (@MainActor () -> Void)?

    /// The offering the paywall was asked to sell, or `nil` for the current one.
    ///
    /// Pass it on to ``PaywallView``, so that the app's own paywall, when it is shown in place
    /// of a RevenueCat one, sells the same products.
    public let offeringIdentifier: String?

    /// Creates a set of handlers.
    ///
    /// - Parameters:
    ///   - onEntitled: Run when a purchase or a restore leaves the customer entitled.
    ///   - onError: Run when a purchase or a restore fails.
    ///   - onDismiss: Run when the customer asks to close the paywall.
    ///   - onPending: Run when a purchase waits for approval.
    ///   - onNothingToRestore: Run when a restore finds nothing.
    ///   - offeringIdentifier: The offering to sell, or `nil` for the current one.
    public init(
        onEntitled: @escaping @MainActor () -> Void,
        onError: @escaping @MainActor (any Error) -> Void,
        onDismiss: @escaping @MainActor () -> Void,
        onPending: (@MainActor () -> Void)? = nil,
        onNothingToRestore: (@MainActor () -> Void)? = nil,
        offeringIdentifier: String? = nil
    ) {
        self.onEntitled = onEntitled
        self.onError = onError
        self.onDismiss = onDismiss
        self.onPending = onPending
        self.onNothingToRestore = onNothingToRestore
        self.offeringIdentifier = offeringIdentifier
    }
}
