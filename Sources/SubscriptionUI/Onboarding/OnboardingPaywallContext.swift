import Foundation
import Subscription

/// What ``OnboardingPaywallStep`` hands to the app's paywall: where it was opened from, the
/// identity of this presentation, and the way to report a purchase or a restore.
///
/// The paywall draws itself and buys through the store as it always does. When a purchase or a
/// restore leaves the customer entitled, it calls ``purchased(_:)`` or ``restored()``, and the step
/// takes it from there: one `paywall_closed`, then the single exit to the rest of the app. The
/// paywall does not dismiss itself and does not draw a close button.
public struct OnboardingPaywallContext {
    /// Where the paywall was opened from. Always `onboarding` (`OnboardingPaywallDecision/source`):
    /// pass it to `trackPaywallImpression(source:offering:)` and put it on the paywall's own events.
    public let source: String

    /// The `pw_id` of this presentation: put it on every `paywall_*` event the paywall sends itself,
    /// such as `paywall_plan_selected` and `paywall_purchase_tapped`, so they join the step's
    /// `paywall_shown` and `paywall_closed`.
    public let paywallId: String

    private let finish: @MainActor (OnboardingPaywallExit) -> Void
    private let working: @MainActor (Bool) -> Void

    init(
        paywallId: String,
        finish: @escaping @MainActor (OnboardingPaywallExit) -> Void,
        working: @escaping @MainActor (Bool) -> Void
    ) {
        self.source = OnboardingPaywallDecision.source
        self.paywallId = paywallId
        self.finish = finish
        self.working = working
    }

    /// Reports a purchase that left the customer entitled. Onboarding moves on.
    ///
    /// Call it only when the returned `SubscriptionStatus` is active: a cancelled purchase keeps the
    /// customer on the paywall, and a pending one (Ask to Buy) is not a purchase yet.
    ///
    /// - Parameter package: The plan that was bought.
    @MainActor
    public func purchased(_ package: SubscriptionPackage) {
        finish(.purchased(package.duration))
    }

    /// Reports a restore that left the customer entitled. Onboarding moves on.
    ///
    /// A restore that finds nothing is not an exit: say so on the paywall and keep it open.
    @MainActor
    public func restored() {
        finish(.restored)
    }

    /// Says whether a purchase or a restore is in flight.
    ///
    /// While it is, the × and "Continue for free" are disabled, so closing cannot race a purchase
    /// that is about to succeed. Set it back to `false` whatever the outcome.
    @MainActor
    public func setWorking(_ isWorking: Bool) {
        working(isWorking)
    }
}
