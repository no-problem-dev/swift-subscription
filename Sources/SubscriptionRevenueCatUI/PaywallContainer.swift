import RevenueCat
import Subscription
import SubscriptionUI
import SwiftUI

/// The one place an app shows its paywall from, whichever paywall that turns out to be.
///
/// ```swift
/// PaywallContainer(
///     mode: .automatic,
///     onEntitled: { analytics.track(.purchaseCompleted) }
/// ) { handlers in
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
///
/// ## Chrome belongs to the custom paywall
///
/// The two paywalls do not want the same frame around them. The app's paywall usually sits in a
/// `NavigationStack` with a title and a close button; a RevenueCat paywall draws its own close
/// button and runs edge to edge, and wrapping it in a navigation bar puts two close buttons on
/// screen. So the container adds no chrome to either, and the `custom` closure returns the app's
/// paywall with its chrome already on. Present the container itself bare, in a sheet.
///
/// ## One set of callbacks
///
/// `onEntitled`, `onError` and `onDismiss` are called for both paywalls. The RevenueCat one is
/// wired to them here; the app's own gets them as the ``PaywallHandlers`` passed to `custom`,
/// to hand on to `PaywallView` and to its close button.
///
/// ## Falling back
///
/// Which paywall is shown is ``PaywallMode/choice(for:)`` applied to what looking up the
/// offering found. Anything that stops the RevenueCat paywall from being shown — no
/// `SubscriptionUseCase` in the environment, the SDK not configured, the offerings failing to
/// load, an offering that is not there — ends at the app's own paywall. For ``PaywallMode/custom``
/// nothing is looked up and the app's paywall appears without a loading state.
public struct PaywallContainer<Custom: View>: View {
    private enum Phase {
        case deciding
        case custom
        case revenueCat(Offering)
    }

    @Environment(\.subscriptionUseCase) private var subscriptionUseCase
    @Environment(\.dismiss) private var dismiss

    private let mode: PaywallMode
    private let onEntitled: (@MainActor () -> Void)?
    private let onError: (@MainActor (any Error) -> Void)?
    private let onDismiss: (@MainActor () -> Void)?
    private let custom: (PaywallHandlers) -> Custom

    @State private var phase: Phase

    /// Creates a container.
    ///
    /// - Parameters:
    ///   - mode: Which paywall the app wants. Changing it decides again.
    ///   - onEntitled: Run when a purchase or a restore leaves the customer entitled, on either
    ///     paywall.
    ///   - onError: Run when a purchase or a restore fails, on either paywall. A cancelled
    ///     purchase does not arrive here, and neither does a failed lookup: that one falls back
    ///     to the app's paywall instead.
    ///   - onDismiss: Run when the customer asks to close either paywall. `nil` dismisses the
    ///     presentation the container is in.
    ///   - custom: Builds the app's own paywall, chrome included, from the handlers to call.
    public init(
        mode: PaywallMode,
        onEntitled: (@MainActor () -> Void)? = nil,
        onError: (@MainActor (any Error) -> Void)? = nil,
        onDismiss: (@MainActor () -> Void)? = nil,
        @ViewBuilder custom: @escaping (PaywallHandlers) -> Custom
    ) {
        self.mode = mode
        self.onEntitled = onEntitled
        self.onError = onError
        self.onDismiss = onDismiss
        self.custom = custom
        self._phase = State(initialValue: mode.needsLookup ? .deciding : .custom)
    }

    public var body: some View {
        content
            .task(id: mode) { await decide() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .deciding:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .custom:
            custom(handlers)
        case .revenueCat(let offering):
            RevenueCatPaywallView(loaded: offering, displayCloseButton: true, handlers: handlers)
                .id(offering.identifier)
        }
    }

    private var handlers: PaywallHandlers {
        PaywallHandlers(
            onEntitled: { onEntitled?() },
            onError: { onError?($0) },
            onDismiss: { if let onDismiss { onDismiss() } else { dismiss() } }
        )
    }

    private func decide() async {
        guard mode.needsLookup else {
            phase = .custom
            return
        }

        var offering: Offering?
        let lookup: PaywallOfferingLookup
        if subscriptionUseCase == nil {
            lookup = .unavailable
        } else {
            do {
                offering = try await RevenueCatOfferingLookup.load(mode.offeringIdentifier)
                lookup = RevenueCatOfferingLookup.lookup(for: offering)
            } catch {
                lookup = .unavailable
            }
        }

        switch (mode.choice(for: lookup), offering) {
        case (.revenueCat, let offering?):
            phase = .revenueCat(offering)
        case (.revenueCat, nil), (.custom, _):
            phase = .custom
        }
    }
}
