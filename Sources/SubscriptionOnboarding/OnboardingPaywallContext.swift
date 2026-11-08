import Foundation
import SubscriptionPlan

/// What ``OnboardingPaywallStep`` hands to the app's paywall: where it was opened from, the
/// identity of this presentation, and the way to report a choice, a purchase or a restore.
///
/// The paywall draws itself and buys through the store as it always does. When a purchase or a
/// restore leaves the customer entitled, it calls ``purchased(_:)`` or ``restored()``, and the step
/// takes it from there: one `paywall_closed`, then the single exit to the rest of the app. The
/// paywall does not dismiss itself and does not draw a close button.
///
/// Everything here takes a plan's length (`PackageDuration`) rather than a RevenueCat package, so
/// a paywall written in a layer that does not import RevenueCat can report to it.
public struct OnboardingPaywallContext {
    /// Where the paywall was opened from. Always `onboarding` (`OnboardingPaywallDecision/source`):
    /// pass it to `trackPaywallImpression(source:offering:)` and put it on the paywall's own events.
    public let source: String

    /// The `pw_id` of this presentation: put it on every `paywall_*` event the paywall sends itself,
    /// such as `paywall_plan_selected` and `paywall_purchase_tapped`, so they join the step's
    /// `paywall_shown` and `paywall_closed`. With ``OnboardingPaywallImpression/byApp`` the app's
    /// own `paywall_shown` carries it too.
    public let paywallId: String

    private let finish: @MainActor (OnboardingPaywallExit) -> Void
    private let working: @MainActor (Bool) -> Void
    private let selection: @MainActor (PackageDuration?) -> Void

    init(
        paywallId: String,
        finish: @escaping @MainActor (OnboardingPaywallExit) -> Void,
        working: @escaping @MainActor (Bool) -> Void,
        selection: @escaping @MainActor (PackageDuration?) -> Void
    ) {
        self.source = OnboardingPaywallEvent.onboardingSource
        self.paywallId = paywallId
        self.finish = finish
        self.working = working
        self.selection = selection
    }

    /// Reports a purchase that left the customer entitled. Onboarding moves on.
    ///
    /// Call it only when the returned `SubscriptionStatus` is active: a cancelled purchase keeps the
    /// customer on the paywall, and a pending one (Ask to Buy) is not a purchase yet.
    ///
    /// - Parameter plan: How long the plan that was bought lasts.
    @MainActor
    public func purchased(_ plan: PackageDuration) {
        finish(.purchased(plan))
    }

    /// Reports a restore that left the customer entitled. Onboarding moves on.
    ///
    /// A restore that finds nothing is not an exit: say so on the paywall and keep it open.
    @MainActor
    public func restored() {
        finish(.restored)
    }

    /// Reports the plan the customer has selected now, so that a `paywall_closed` without a
    /// purchase still says which plan was in front of them (`product`).
    ///
    /// Call it with the plan selected when the paywall first draws its plans, and again on every
    /// change. `nil` when no plan is selected, such as before the prices have loaded.
    @MainActor
    public func select(_ plan: PackageDuration?) {
        selection(plan)
    }

    /// Says whether a purchase or a restore is in flight.
    ///
    /// While it is, the ×, "Restore Purchases" and "Continue for free" are disabled, so closing
    /// cannot race a purchase that is about to succeed. Set it back to `false` whatever the outcome.
    @MainActor
    public func setWorking(_ isWorking: Bool) {
        working(isWorking)
    }
}
