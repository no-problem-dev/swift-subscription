import Foundation
import RevenueCat
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

    @Test("ペイウォールが付いているかは Offering.hasPaywall で判定する")
    func hasPaywall() {
        #expect(RevenueCatOfferingLookup.lookup(for: Self.offering("plain")) == .noPaywall)
        #expect(RevenueCatOfferingLookup.lookup(for: Self.offering("designed", paywall: Self.paywall)) == .hasPaywall)
    }
}
