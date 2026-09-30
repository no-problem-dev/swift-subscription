import Subscription
import XCTest

/// Covers the entitlement decision a process without a use case — a widget reading the app's
/// `EntitlementCache` — makes through the public API alone. Deliberately not `@testable`.
final class WidgetEntitlementTests: XCTestCase {
    private static let confirmedAt = Date(timeIntervalSince1970: 1_800_000_000)
    private static let day: TimeInterval = 24 * 60 * 60

    private static func record(expiringAt expiration: Date?) -> CachedEntitlement {
        CachedEntitlement(
            isActive: true,
            entitlementId: "premium",
            packageId: "annual",
            expirationDate: expiration,
            userId: nil,
            confirmedAt: confirmedAt
        )
    }

    func test_ウィジェットは猶予の中なら期限を過ぎても有料と判定する() {
        let expiration = Self.confirmedAt.addingTimeInterval(Self.day)
        let record = Self.record(expiringAt: expiration)

        let status = record.lastKnownStatus(at: expiration.addingTimeInterval(2 * Self.day))

        XCTAssertTrue(status.isActive)
        XCTAssertEqual(status.verification, .lastKnown(at: Self.confirmedAt))
    }

    func test_ウィジェットは猶予を過ぎたら無料と判定する() {
        let expiration = Self.confirmedAt.addingTimeInterval(Self.day)
        let record = Self.record(expiringAt: expiration)

        let status = record.lastKnownStatus(gracePeriod: 0, at: expiration.addingTimeInterval(1))

        XCTAssertFalse(status.isActive)
    }
}
