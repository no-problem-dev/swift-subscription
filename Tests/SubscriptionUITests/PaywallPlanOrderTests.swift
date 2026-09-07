import Subscription
import XCTest
@testable import SubscriptionUI

/// Covers how a paywall arranges an offering it loaded itself: which plan leads, and which one
/// is preselected and badged.
final class PaywallPlanOrderTests: XCTestCase {
    private static func package(_ id: String, _ duration: PackageDuration) -> SubscriptionPackage {
        SubscriptionPackage(
            id: id,
            title: id,
            description: "",
            price: "¥1,000",
            pricePerMonth: duration == .annual ? "¥83" : nil,
            duration: duration
        )
    }

    // MARK: - Ordering

    func test_年額が先頭に来る() {
        let packages = [
            Self.package("monthly", .monthly),
            Self.package("lifetime", .lifetime),
            Self.package("annual", .annual)
        ]

        let ordered = PaywallPlanOrder.annualFirst(packages)

        XCTAssertEqual(ordered.map(\.id), ["annual", "monthly", "lifetime"])
    }

    func test_年額以外の並びはダッシュボードの順を保つ() {
        let packages = [
            Self.package("lifetime", .lifetime),
            Self.package("weekly", .unknown),
            Self.package("monthly", .monthly)
        ]

        let ordered = PaywallPlanOrder.annualFirst(packages)

        XCTAssertEqual(
            ordered.map(\.id),
            ["lifetime", "weekly", "monthly"],
            "年額が無いなら並べ替える理由が無い"
        )
    }

    // MARK: - What gets preselected

    func test_推すのは年額() {
        let packages = [
            Self.package("monthly", .monthly),
            Self.package("annual", .annual)
        ]

        XCTAssertEqual(PaywallPlanOrder.recommended(in: packages)?.id, "annual")
    }

    /// An offering with no annual plan still has to preselect something, or the purchase button
    /// is disabled on a paywall that has plans to sell.
    func test_年額が無ければ先頭を推す() {
        let packages = [
            Self.package("monthly", .monthly),
            Self.package("lifetime", .lifetime)
        ]

        XCTAssertEqual(PaywallPlanOrder.recommended(in: packages)?.id, "monthly")
    }

    /// Nothing to sell is a dashboard problem — no offering marked current, or one with no
    /// packages attached — and it has to be survivable rather than a crash.
    func test_売るものが無ければ推す相手もいない() {
        XCTAssertNil(PaywallPlanOrder.recommended(in: []))
        XCTAssertEqual(PaywallPlanOrder.annualFirst([]).count, 0)
    }
}
