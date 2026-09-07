import Foundation
import Subscription

/// How ``PaywallView`` arranges an offering it loaded itself.
///
/// Which offering is current is a server-side decision and its packages arrive in whatever
/// order the dashboard lists them, which is often the order someone happened to add them in.
/// A paywall that leads with the annual plan is the common arrangement for a reason: it is the
/// one the app would rather sell, and putting it first is what makes the rest read as
/// alternatives to it rather than the other way round.
enum PaywallPlanOrder {
    /// The annual packages first, everything else after, each group keeping its given order.
    static func annualFirst(_ packages: [SubscriptionPackage]) -> [SubscriptionPackage] {
        packages.filter { $0.duration == .annual } + packages.filter { $0.duration != .annual }
    }

    /// The plan to preselect and badge: the first annual one, or the first of any kind.
    ///
    /// `nil` only when there is nothing to sell, which is a dashboard problem — an offering
    /// with no packages attached, or none marked current.
    static func recommended(in packages: [SubscriptionPackage]) -> SubscriptionPackage? {
        packages.first { $0.duration == .annual } ?? packages.first
    }
}
