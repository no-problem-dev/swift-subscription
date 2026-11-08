import Foundation
import SubscriptionPlan

/// An analytics event from the paywall at the end of onboarding, named and shaped as the shared
/// event catalog names and shapes it.
///
/// This package depends on no analytics SDK. ``OnboardingPaywallStep`` hands each event to a
/// closure, and the app sends it with whatever it sends events with: switch over the case for
/// typed values, or forward ``name`` and ``parameters`` as they are.
///
/// ```swift
/// OnboardingPaywallStep(onEvent: { event in
///     analytics.send(event.name, event.parameters)
/// }, onFinish: { _ in showHome() }) { context in … }
/// ```
///
/// Both events carry `source=onboarding` and the same `pw_id`, which ties a close to the
/// impression it ends. The app adds what only it knows, such as `nth`, before sending.
///
/// `.closed` names a `product` only when a plan was bought. To say which plan was selected when the
/// customer closed without buying, report the selection with ``OnboardingPaywallContext/select(_:)``
/// and send `paywall_closed` from ``OnboardingPaywallStep``'s `onClose` (an
/// ``OnboardingPaywallClose``) instead of from `.closed`.
public enum OnboardingPaywallEvent: Sendable, Hashable {
    /// `paywall_shown`: the paywall has been on screen for a second, the catalog's impression.
    ///
    /// Not sent with ``OnboardingPaywallImpression/byApp``, where the app sends `paywall_shown`
    /// itself.
    case shown(paywallId: String)

    /// `paywall_closed`: the customer left it, after `openSeconds` whole seconds on screen.
    case closed(paywallId: String, exit: OnboardingPaywallExit, openSeconds: Int)

    /// The event's name in the catalog.
    public var name: String {
        switch self {
        case .shown: "paywall_shown"
        case .closed: "paywall_closed"
        }
    }

    /// Where the paywall was opened from. Always `onboarding` (`OnboardingPaywallDecision/source`).
    public var source: String {
        Self.onboardingSource
    }

    /// `OnboardingPaywallDecision/source`, which this module cannot see because it lives beside
    /// RevenueCat. A test keeps the two equal.
    static let onboardingSource = "onboarding"

    /// The `pw_id` that ties together the events of one presentation: eight lowercase hex digits.
    public var paywallId: String {
        switch self {
        case .shown(let paywallId), .closed(let paywallId, _, _): paywallId
        }
    }

    /// The event's parameters under the catalog's names, with every value as text.
    ///
    /// `paywall_shown` has `source` and `pw_id`. `paywall_closed` adds `result`, `via`, `open_s`,
    /// and `product` when a plan was bought.
    public var parameters: [String: String] {
        var parameters = ["source": source, "pw_id": paywallId]
        if case .closed(_, let exit, let openSeconds) = self {
            parameters["result"] = exit.result
            parameters["via"] = exit.via
            parameters["open_s"] = String(openSeconds)
            if let product = exit.product { parameters["product"] = product }
        }
        return parameters
    }

    /// A new `pw_id`: eight lowercase hex digits.
    static func makePaywallId() -> String {
        String(UUID().uuidString.lowercased().filter { $0 != "-" }.prefix(8))
    }

    /// The seconds the paywall stays on screen before `paywall_shown` counts it as seen, as the
    /// catalog's impressions do.
    static let impressionDwell: Duration = .seconds(1)

    /// Whole seconds between the paywall appearing and the customer leaving it, never negative.
    /// `0` when it never appeared.
    static func openSeconds(from shownAt: Date?, to closedAt: Date) -> Int {
        guard let shownAt else { return 0 }
        return max(0, Int(closedAt.timeIntervalSince(shownAt).rounded(.down)))
    }
}

/// How the customer left the paywall at the end of onboarding, with the plan they had selected:
/// the `paywall_closed` that ``OnboardingPaywallStep`` hands to `onClose`.
///
/// The same close as ``OnboardingPaywallEvent/closed(paywallId:exit:openSeconds:)``, plus the plan
/// the paywall last reported through ``OnboardingPaywallContext/select(_:)``. Send this one or that
/// one, not both.
public struct OnboardingPaywallClose: Sendable, Hashable {
    /// The `pw_id` of this presentation.
    public let paywallId: String

    /// How the customer left.
    public let exit: OnboardingPaywallExit

    /// Whole seconds between the paywall appearing and the customer leaving it.
    public let openSeconds: Int

    /// The plan selected when the customer left, or `nil` when the paywall never reported one.
    public let selectedPlan: PackageDuration?

    /// Creates a close.
    public init(paywallId: String, exit: OnboardingPaywallExit, openSeconds: Int, selectedPlan: PackageDuration?) {
        self.paywallId = paywallId
        self.exit = exit
        self.openSeconds = openSeconds
        self.selectedPlan = selectedPlan
    }

    /// The event's name in the catalog: `paywall_closed`.
    public var name: String { "paywall_closed" }

    /// Where the paywall was opened from. Always `onboarding`.
    public var source: String { OnboardingPaywallEvent.onboardingSource }

    /// The `product` of `paywall_closed`: the plan bought, or, when the customer closed without
    /// buying, the plan selected then. `nil` after a restore, when no plan was reported, and for a
    /// plan the catalog does not name (`PackageDuration/unknown`).
    public var product: String? {
        switch exit {
        case .purchased: exit.product
        case .closeButton, .continueFree: selectedPlan.flatMap(OnboardingPaywallExit.product(of:))
        case .restored: nil
        }
    }

    /// The same close as an ``OnboardingPaywallEvent``, without the selected plan.
    public var event: OnboardingPaywallEvent {
        .closed(paywallId: paywallId, exit: exit, openSeconds: openSeconds)
    }

    /// The event's parameters under the catalog's names, with every value as text: `source`,
    /// `pw_id`, `result`, `via`, `open_s`, and `product` when there is one.
    public var parameters: [String: String] {
        var parameters = event.parameters
        parameters["product"] = product
        return parameters
    }
}
