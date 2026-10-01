import Foundation
import RevenueCat
import RevenueCatUI
import SubscriptionUI
import Testing
@testable import SubscriptionRevenueCatUI

@Suite("RevenueCat の offering を探す")
struct RevenueCatOfferingLookupTests {
    private static func offering(_ identifier: String, paywall: PaywallData? = nil) -> Offering {
        Offering(
            identifier: identifier,
            serverDescription: identifier,
            paywall: paywall,
            availablePackages: [],
            webCheckoutUrl: nil
        )
    }

    private static let paywall = PaywallData(
        templateName: "1",
        config: PaywallData.Configuration(
            packages: ["$rc_annual"],
            images: PaywallData.Configuration.Images(),
            colors: PaywallData.Configuration.ColorInformation(
                light: PaywallData.Configuration.Colors(
                    background: "#FFFFFF",
                    text1: "#000000",
                    callToActionBackground: "#000000",
                    callToActionForeground: "#FFFFFF"
                )
            )
        ),
        localization: PaywallData.LocalizedConfiguration(title: "Title", callToAction: "Continue"),
        assetBaseURL: URL(string: "https://example.com")!
    )

    @Test("指定が無ければ current")
    func currentWhenUnspecified() {
        let current = Self.offering("default")
        let found = RevenueCatOfferingLookup.offering(
            nil,
            all: ["default": current, "summer": Self.offering("summer")],
            current: current
        )
        #expect(found?.identifier == "default")
    }

    @Test("指定があればその offering で、current ではない")
    func namedOffering() {
        let current = Self.offering("default")
        let found = RevenueCatOfferingLookup.offering(
            "summer",
            all: ["default": current, "summer": Self.offering("summer")],
            current: current
        )
        #expect(found?.identifier == "summer")
    }

    @Test("指定した offering がダッシュボードに無ければ、current で代用しない")
    func missingNamedOffering() {
        let current = Self.offering("default")
        let found = RevenueCatOfferingLookup.offering("winter", all: ["default": current], current: current)
        #expect(found == nil)
        #expect(RevenueCatOfferingLookup.lookup(for: found) == .offeringMissing)
    }

    @Test("current が無いときは offering が無い扱い")
    func noCurrent() {
        let found = RevenueCatOfferingLookup.offering(nil, all: [:], current: nil)
        #expect(RevenueCatOfferingLookup.lookup(for: found) == .offeringMissing)
    }

    @Test("placement を指定したら、その placement に配られた offering")
    func placementServesItsOffering() {
        let current = Self.offering("default")
        let gate = Self.offering("gate")
        let found = RevenueCatOfferingLookup.offering(
            "summer",
            placement: "feature_gate",
            all: ["default": current, "gate": gate, "summer": Self.offering("summer")],
            current: current,
            served: { $0 == "feature_gate" ? gate : nil }
        )
        #expect(found?.identifier == "gate")
    }

    @Test("placement に何も配らない設定なら offering が無い扱い（自前のペイウォールに戻る）")
    func placementServesNothing() {
        let current = Self.offering("default")
        let found = RevenueCatOfferingLookup.offering(
            nil,
            placement: "feature_gate",
            all: ["default": current],
            current: current,
            served: { _ in nil }
        )
        #expect(RevenueCatOfferingLookup.lookup(for: found) == .offeringMissing)
    }

    @Test("placement が無ければ offering の指定で探す")
    func noPlacementUsesIdentifier() {
        let current = Self.offering("default")
        let found = RevenueCatOfferingLookup.offering(
            "summer",
            placement: nil,
            all: ["default": current, "summer": Self.offering("summer")],
            current: current,
            served: { _ in Issue.record("placement を探した"); return nil }
        )
        #expect(found?.identifier == "summer")
    }

    @Test("ペイウォールが付いているかは Offering.hasPaywall で判定する")
    func hasPaywall() {
        #expect(RevenueCatOfferingLookup.lookup(for: Self.offering("plain")) == .noPaywall)
        #expect(RevenueCatOfferingLookup.lookup(for: Self.offering("designed", paywall: Self.paywall)) == .hasPaywall)
    }
}

@Suite("カスタム変数を RevenueCat の値に変える")
struct PaywallVariableTests {
    @Test("文字・数・真偽を同じ種類の値にする")
    func sameKind() {
        #expect(PaywallVariable.string("9/17").revenueCatValue == .string("9/17"))
        #expect(PaywallVariable.number(7).revenueCatValue == .number(7))
        #expect(PaywallVariable.bool(true).revenueCatValue == .bool(true))
        #expect(PaywallVariable("見出し").revenueCatValue.stringValue == "見出し")
    }
}

@Suite("RevenueCat のペイウォールが失敗として返す購入")
struct RevenueCatPurchaseErrorTests {
    @Test("承認待ちは失敗でなく purchasePending")
    func pendingIsNotAFailure() {
        let error = RevenueCatPurchaseError.subscriptionError(ErrorCode.paymentPendingError)

        guard case .purchasePending = error else {
            Issue.record("expected .purchasePending, got \(error)")
            return
        }
    }

    @Test("ほかは purchaseFailed")
    func otherErrorsAreFailures() {
        let error = RevenueCatPurchaseError.subscriptionError(ErrorCode.storeProblemError)

        guard case .purchaseFailed = error else {
            Issue.record("expected .purchaseFailed, got \(error)")
            return
        }
    }
}
