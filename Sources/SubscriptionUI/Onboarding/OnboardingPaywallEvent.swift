import Foundation
import Subscription

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
public enum OnboardingPaywallEvent: Sendable, Hashable {
    /// `paywall_shown`: the paywall appeared.
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
        OnboardingPaywallDecision.source
    }

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

    /// Whole seconds between the paywall appearing and the customer leaving it, never negative.
    /// `0` when it never appeared.
    static func openSeconds(from shownAt: Date?, to closedAt: Date) -> Int {
        guard let shownAt else { return 0 }
        return max(0, Int(closedAt.timeIntervalSince(shownAt).rounded(.down)))
    }
}
