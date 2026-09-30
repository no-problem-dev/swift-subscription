import RevenueCat
import RevenueCatUI
import Subscription
import SubscriptionUI
import SwiftUI

/// No offering by the identifier a RevenueCat paywall asked for.
public enum RevenueCatPaywallError: Error, LocalizedError {
    /// The offerings loaded without this one: an identifier that is not in the dashboard, or,
    /// for `nil`, no offering marked current.
    case offeringNotFound(String?)

    /// The message shown by `localizedDescription`. Hard-coded English, like
    /// `SubscriptionError`'s; map the case to your own copy rather than displaying it.
    public var errorDescription: String? {
        switch self {
        case .offeringNotFound(let identifier?):
            return "No offering was found with the identifier \(identifier)."
        case .offeringNotFound(nil):
            return "No offering is marked current."
        }
    }
}

/// A paywall designed in the RevenueCat dashboard with RevenueCat Paywalls, reporting in the
/// same callbacks as `PaywallView`.
///
/// ```swift
/// RevenueCatPaywallView(
///     offering: nil,
///     onEntitled: { dismiss() },
///     onError: { presentedError = $0 }
/// )
/// ```
///
/// RevenueCatUI buys and restores through `Purchases.shared` itself. What this view adds is the
/// answer to "is the customer entitled now?", which it takes from the `SubscriptionUseCase` in
/// the environment rather than from the `CustomerInfo` RevenueCatUI hands back: the use case
/// knows which entitlement means subscribed, and asking it writes the new reading to the
/// `EntitlementCache` too. A restore that finds nothing therefore calls `onNothingToRestore`,
/// not `onEntitled`.
///
/// It draws its own chrome. Present it bare in a sheet — not inside a `NavigationStack` with a
/// close button of your own — and the dashboard's close button calls `onDismiss`.
///
/// With no use case in the environment, or before the SDK is configured, it renders an error
/// and reports it to `onError`. `PaywallContainer` falls back to the app's own paywall in both
/// cases instead.
public struct RevenueCatPaywallView: View {
    private enum Phase {
        case loading
        case loaded(Offering)
        case failed(any Error)
    }

    @Environment(\.subscriptionUseCase) private var subscriptionUseCase
    @Environment(\.dismiss) private var dismiss

    private let offeringIdentifier: String?
    private let displayCloseButton: Bool
    private let onEntitled: (@MainActor () -> Void)?
    private let onError: (@MainActor (any Error) -> Void)?
    private let onDismiss: (@MainActor () -> Void)?
    private let onPending: (@MainActor () -> Void)?
    private let onNothingToRestore: (@MainActor () -> Void)?

    @State private var phase: Phase

    /// Creates a paywall for an offering.
    ///
    /// - Parameters:
    ///   - offering: The offering's dashboard identifier, or `nil` for the current offering.
    ///   - displayCloseButton: Whether RevenueCatUI adds a close button to a template paywall.
    ///     A paywall built with the components editor carries the close button it was designed
    ///     with and ignores this.
    ///   - onEntitled: Run when a purchase or a restore leaves the customer entitled.
    ///   - onError: Run when the offering cannot be loaded, or a purchase or a restore fails.
    ///     A cancelled purchase does not arrive here.
    ///   - onDismiss: Run when the paywall's close button is tapped. `nil` dismisses the
    ///     presentation the paywall is in.
    ///   - onPending: Run when a purchase waits for approval (Ask to Buy). `nil` reports
    ///     `SubscriptionError.purchasePending` to `onError` instead.
    ///   - onNothingToRestore: Run when a restore finds nothing that entitles the customer.
    public init(
        offering: String? = nil,
        displayCloseButton: Bool = true,
        onEntitled: (@MainActor () -> Void)? = nil,
        onError: (@MainActor (any Error) -> Void)? = nil,
        onDismiss: (@MainActor () -> Void)? = nil,
        onPending: (@MainActor () -> Void)? = nil,
        onNothingToRestore: (@MainActor () -> Void)? = nil
    ) {
        self.offeringIdentifier = offering
        self.displayCloseButton = displayCloseButton
        self.onEntitled = onEntitled
        self.onError = onError
        self.onDismiss = onDismiss
        self.onPending = onPending
        self.onNothingToRestore = onNothingToRestore
        self._phase = State(initialValue: .loading)
    }

    init(
        loaded offering: Offering,
        displayCloseButton: Bool,
        handlers: PaywallHandlers
    ) {
        self.offeringIdentifier = offering.identifier
        self.displayCloseButton = displayCloseButton
        self.onEntitled = handlers.onEntitled
        self.onError = handlers.onError
        self.onDismiss = handlers.onDismiss
        self.onPending = handlers.onPending
        self.onNothingToRestore = handlers.onNothingToRestore
        self._phase = State(initialValue: .loaded(offering))
    }

    public var body: some View {
        switch phase {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task { await load() }
        case .loaded(let offering):
            PaywallView(offering: offering, displayCloseButton: displayCloseButton)
                .onPurchaseCompleted { _ in
                    Task { await settle(afterRestore: false) }
                }
                .onRestoreCompleted { _ in
                    Task { await settle(afterRestore: true) }
                }
                .onPurchaseFailure { error in
                    report(RevenueCatPurchaseError.subscriptionError(error))
                }
                .onRestoreFailure { error in
                    onError?(SubscriptionError.restoreFailed(error))
                }
                .onRequestedDismissal {
                    if let onDismiss { onDismiss() } else { dismiss() }
                }
        case .failed(let error):
            ContentUnavailableView(
                "Paywall unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text(error.localizedDescription)
            )
        }
    }

    private func load() async {
        guard subscriptionUseCase != nil else {
            fail(SubscriptionError.notConfigured)
            return
        }

        do {
            guard let offering = try await RevenueCatOfferingLookup.load(offeringIdentifier) else {
                fail(RevenueCatPaywallError.offeringNotFound(offeringIdentifier))
                return
            }
            phase = .loaded(offering)
        } catch {
            fail(error)
        }
    }

    private func report(_ error: SubscriptionError) {
        if case .purchasePending = error, let onPending {
            onPending()
        } else {
            onError?(error)
        }
    }

    private func fail(_ error: any Error) {
        phase = .failed(error)
        onError?(error)
    }

    /// Asks the use case rather than reading the `CustomerInfo` RevenueCatUI passed, because
    /// only the use case knows which entitlement counts. A restore that finds nothing succeeds,
    /// and branching on the success alone would tell someone who never subscribed that they had
    /// been restored.
    private func settle(afterRestore: Bool) async {
        guard let subscriptionUseCase else {
            onError?(SubscriptionError.notConfigured)
            return
        }

        do {
            let status = try await subscriptionUseCase.checkSubscriptionStatus()
            if status.isActive {
                onEntitled?()
            } else if afterRestore {
                onNothingToRestore?()
            }
        } catch {
            onError?(error)
        }
    }
}

/// What a purchase RevenueCatUI reports as failed means.
enum RevenueCatPurchaseError {
    /// A deferred purchase — Ask to Buy — is reported by the SDK as a failure; it is not one.
    static func subscriptionError(_ error: any Error) -> SubscriptionError {
        if let code = error as? ErrorCode, code == .paymentPendingError {
            return .purchasePending
        }
        return .purchaseFailed(error)
    }
}
