import Foundation

/// Whether the paywall at the end of onboarding is shown, and why not when it is not.
///
/// Every app ends its onboarding on a paywall the customer can close, and the same three things
/// keep it off the screen: the customer is already entitled, the dashboard switched it off, or
/// there is nothing to sell. ``decide(offering:status:)`` is that rule, written once.
///
/// ```swift
/// let offering = try? await subscriptionUseCase.loadOffering(placement: OnboardingPaywallDecision.placement)
/// let status = await subscriptionUseCase.getSubscriptionStatus()
/// switch OnboardingPaywallDecision.decide(offering: offering, status: status) {
/// case .show:
///     steps.append(.paywall)
/// case .skip:
///     break  // go straight to the screen onboarding promised
/// }
/// ```
///
/// The switch is the offering's metadata entry ``metadataKey`` (`onboarding_paywall`). Set it to
/// `"off"` on the offering served at the ``placement`` to stop the paywall without an app
/// release, or on one side of an Experiment to compare onboarding with and without it. Any other
/// value, or no entry, leaves it on: showing the paywall is the default for every app, and a typo
/// in the dashboard must not quietly take it away. A non-string value (a JSON `false`) is not
/// read, because ``SubscriptionOffering/metadata`` keeps strings only; it too leaves the paywall
/// on, and its key is in ``SubscriptionOffering/droppedMetadataKeys``.
///
/// Decide once per install, when onboarding starts, and keep the answer for the rest of it, so a
/// dashboard change half-way through does not mix the two sides of the funnel.
public enum OnboardingPaywallDecision: Sendable, Hashable {
    /// End onboarding on the paywall.
    case show

    /// Leave the paywall out and go straight to the screen onboarding promised.
    case skip(OnboardingPaywallSkipReason)

    /// The placement to load the onboarding paywall's offering from, and to name in the dashboard.
    public static let placement = "onboarding"

    /// The `source` of every paywall event at the end of onboarding, and the `source` to pass to
    /// ``SubscriptionUseCase/trackPaywallImpression(source:offering:)``.
    public static let source = "onboarding"

    /// The offering metadata entry that switches the paywall off when its value is ``switchedOffValue``.
    public static let metadataKey = "onboarding_paywall"

    /// The metadata value that switches the paywall off, compared without regard to case or to
    /// surrounding whitespace.
    public static let switchedOffValue = "off"

    /// Whether the paywall is shown.
    public var shows: Bool {
        self == .show
    }

    /// Decides whether onboarding ends on the paywall.
    ///
    /// The reasons are checked in this order, and the first that applies is the one reported:
    ///
    /// | | reported as |
    /// |---|---|
    /// | `status.isActive` | ``OnboardingPaywallSkipReason/entitled`` |
    /// | no offering | ``OnboardingPaywallSkipReason/nothingToSell`` |
    /// | ``metadataKey`` is ``switchedOffValue`` | ``OnboardingPaywallSkipReason/switchedOff`` |
    /// | the offering has no packages | ``OnboardingPaywallSkipReason/nothingToSell`` |
    ///
    /// A status that has not been verified yet and is not active counts as not entitled. That is
    /// what a first launch holds, and it is exactly the customer the paywall is for.
    ///
    /// - Parameters:
    ///   - offering: The offering the paywall would sell, normally the one served at
    ///     ``placement``. `nil` when it could not be loaded: a paywall without prices is not shown.
    ///   - status: The customer's entitlement as the app knows it now.
    /// - Returns: Whether to show the paywall.
    public static func decide(offering: SubscriptionOffering?, status: SubscriptionStatus) -> OnboardingPaywallDecision {
        if status.isActive { return .skip(.entitled) }
        guard let offering else { return .skip(.nothingToSell) }
        if isSwitchedOff(offering.metadata[metadataKey]) { return .skip(.switchedOff) }
        if offering.packages.isEmpty { return .skip(.nothingToSell) }
        return .show
    }

    static func isSwitchedOff(_ value: String?) -> Bool {
        guard let value else { return false }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == switchedOffValue
    }
}

/// Why the paywall at the end of onboarding was left out.
///
/// The raw values are stable identifiers for logging and analytics.
public enum OnboardingPaywallSkipReason: String, Sendable, Hashable, CaseIterable {
    /// The customer is already entitled. Selling them what they have is not a paywall, it is noise.
    case entitled

    /// The offering's metadata switched the paywall off.
    case switchedOff = "switched_off"

    /// No offering, or one with no packages: there is no price to show, so there is nothing to sell.
    case nothingToSell = "nothing_to_sell"
}
