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
/// `onEntitled`, `onError`, `onDismiss`, `onPending` and `onNothingToRestore` are called for
/// both paywalls. The RevenueCat one is wired to them here; the app's own gets them as the
/// ``PaywallHandlers`` passed to `custom`, to hand on to `PaywallView` and to its close button.
///
/// The handlers also carry the mode's offering identifier. Passing it to `PaywallView` keeps
/// the fallback selling the offering the mode named, not the current one.
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
    private let variables: [String: PaywallVariable]
    private let onEntitled: (@MainActor () -> Void)?
    private let onEntitledStatus: (@MainActor (SubscriptionStatus) -> Void)?
    private let onError: (@MainActor (any Error) -> Void)?
    private let onDismiss: (@MainActor () -> Void)?
    private let onPending: (@MainActor () -> Void)?
    private let onNothingToRestore: (@MainActor () -> Void)?
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
    ///   - onPending: Run when a purchase waits for approval (Ask to Buy), on either paywall.
    ///     `nil` reports `SubscriptionError.purchasePending` to `onError` instead.
    ///   - onNothingToRestore: Run when a restore finds nothing, on either paywall.
    ///   - custom: Builds the app's own paywall, chrome included, from the handlers to call.
    public init(
        mode: PaywallMode,
        onEntitled: (@MainActor () -> Void)? = nil,
        onError: (@MainActor (any Error) -> Void)? = nil,
        onDismiss: (@MainActor () -> Void)? = nil,
        onPending: (@MainActor () -> Void)? = nil,
        onNothingToRestore: (@MainActor () -> Void)? = nil,
        @ViewBuilder custom: @escaping (PaywallHandlers) -> Custom
    ) {
        self.mode = mode
        self.variables = [:]
        self.onEntitled = onEntitled
        self.onEntitledStatus = nil
        self.onError = onError
        self.onDismiss = onDismiss
        self.onPending = onPending
        self.onNothingToRestore = onNothingToRestore
        self.custom = custom
        self._phase = State(initialValue: mode.needsLookup ? .deciding : .custom)
    }

    /// Creates a container that hands custom variables to the RevenueCat paywall and reports
    /// what the customer is entitled to.
    ///
    /// - Parameters:
    ///   - mode: Which paywall the app wants. Changing it decides again.
    ///   - variables: The values shown where the dashboard paywall says `{{ custom.name }}`, by
    ///     name. The app's own paywall does not read them. Pass `[:]` to hear the status alone.
    ///   - onEntitled: Run with the subscription status when a purchase or a restore leaves the
    ///     customer entitled, on either paywall. `SubscriptionStatus.activePackageId` is the
    ///     store product that was bought, which tells a trial on the annual plan from a monthly
    ///     purchase. With no `SubscriptionUseCase` in the environment the status carries
    ///     `isActive` alone.
    ///   - onError: Run when a purchase or a restore fails, on either paywall.
    ///   - onDismiss: Run when the customer asks to close either paywall. `nil` dismisses the
    ///     presentation the container is in.
    ///   - onPending: Run when a purchase waits for approval (Ask to Buy), on either paywall.
    ///   - onNothingToRestore: Run when a restore finds nothing, on either paywall.
    ///   - custom: Builds the app's own paywall, chrome included, from the handlers to call.
    public init(
        mode: PaywallMode,
        variables: [String: PaywallVariable],
        onEntitled: (@MainActor (SubscriptionStatus) -> Void)? = nil,
        onError: (@MainActor (any Error) -> Void)? = nil,
        onDismiss: (@MainActor () -> Void)? = nil,
        onPending: (@MainActor () -> Void)? = nil,
        onNothingToRestore: (@MainActor () -> Void)? = nil,
        @ViewBuilder custom: @escaping (PaywallHandlers) -> Custom
    ) {
        self.mode = mode
        self.variables = variables
        self.onEntitled = nil
        self.onEntitledStatus = onEntitled
        self.onError = onError
        self.onDismiss = onDismiss
        self.onPending = onPending
        self.onNothingToRestore = onNothingToRestore
        self.custom = custom
        self._phase = State(initialValue: mode.needsLookup ? .deciding : .custom)
    }

    public var body: some View {
        content
            .paywallVariables(variables)
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
            RevenueCatPaywallView(
                loaded: offering,
                displayCloseButton: true,
                handlers: handlers,
                onEntitledStatus: onEntitledStatus
            )
            .id(offering.identifier)
        }
    }

    private var handlers: PaywallHandlers {
        PaywallHandlers(
            onEntitled: { entitled() },
            onError: { onError?($0) },
            onDismiss: { if let onDismiss { onDismiss() } else { dismiss() } },
            onPending: onPending,
            onNothingToRestore: onNothingToRestore,
            offeringIdentifier: mode.offeringIdentifier
        )
    }

    private func entitled() {
        guard let onEntitledStatus else {
            onEntitled?()
            return
        }
        guard let subscriptionUseCase else {
            onEntitledStatus(SubscriptionStatus(isActive: true))
            return
        }
        Task { @MainActor in
            onEntitledStatus(await subscriptionUseCase.getSubscriptionStatus())
        }
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
                offering = try await RevenueCatOfferingLookup.load(
                    mode.offeringIdentifier,
                    placement: mode.placementIdentifier
                )
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
