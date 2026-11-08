import Foundation
import Subscription
import Testing

@Suite("オンボーディングの最後にペイウォールを出すか")
struct OnboardingPaywallDecisionTests {
    private static let annual = SubscriptionPackage(
        id: "annual", title: "Annual", description: "", price: "¥6,000", pricePerMonth: "¥500", duration: .annual
    )

    private static func offering(
        metadata: [String: String] = [:],
        droppedMetadataKeys: Set<String> = [],
        packages: [SubscriptionPackage] = [annual]
    ) -> SubscriptionOffering {
        SubscriptionOffering(
            id: "default",
            packages: packages,
            metadata: metadata,
            droppedMetadataKeys: droppedMetadataKeys,
            servedBy: .placement(OnboardingPaywallDecision.placement)
        )
    }

    private static let entitled = SubscriptionStatus(isActive: true, verification: .confirmed(at: Date()))

    @Test("売る物があり、購読していなければ出す")
    func showsByDefault() {
        let decision = OnboardingPaywallDecision.decide(offering: Self.offering(), status: .inactive)
        #expect(decision == .show)
        #expect(decision.shows)
    }

    @Test("確かめる前の未購読（初回の起動）でも出す")
    func showsBeforeVerification() {
        let status = SubscriptionStatus(isActive: false, verification: .unverified)
        #expect(OnboardingPaywallDecision.decide(offering: Self.offering(), status: status) == .show)
    }

    @Test("購読中の人には出さない")
    func skipsWhenEntitled() {
        let decision = OnboardingPaywallDecision.decide(offering: Self.offering(), status: Self.entitled)
        #expect(decision == .skip(.entitled))
        #expect(!decision.shows)
    }

    @Test("metadata の onboarding_paywall が off なら出さない", arguments: ["off", "OFF", "Off", " off\n"])
    func skipsWhenSwitchedOff(_ value: String) {
        let offering = Self.offering(metadata: ["onboarding_paywall": value])
        #expect(OnboardingPaywallDecision.decide(offering: offering, status: .inactive) == .skip(.switchedOff))
    }

    @Test("off 以外の値・書き損じは出す", arguments: ["on", "", "of", "false", "0", "disabled"])
    func showsForAnyOtherValue(_ value: String) {
        let offering = Self.offering(metadata: ["onboarding_paywall": value])
        #expect(OnboardingPaywallDecision.decide(offering: offering, status: .inactive) == .show)
    }

    @Test("文字列でない値（JSON の false）は読めないので出す")
    func showsWhenValueIsNotText() {
        let offering = Self.offering(droppedMetadataKeys: ["onboarding_paywall"])
        #expect(OnboardingPaywallDecision.decide(offering: offering, status: .inactive) == .show)
    }

    @Test("ほかの鍵の off では止まらない")
    func ignoresOtherKeys() {
        let offering = Self.offering(metadata: ["paywall": "off", "appeal": "off"])
        #expect(OnboardingPaywallDecision.decide(offering: offering, status: .inactive) == .show)
    }

    @Test("offering が読めなければ出さない")
    func skipsWithoutOffering() {
        #expect(OnboardingPaywallDecision.decide(offering: nil, status: .inactive) == .skip(.nothingToSell))
    }

    @Test("商品の無い offering では出さない")
    func skipsWithoutPackages() {
        let offering = Self.offering(packages: [])
        #expect(OnboardingPaywallDecision.decide(offering: offering, status: .inactive) == .skip(.nothingToSell))
    }

    @Test("理由が重なったら、購読中・offering 無し・off・商品無しの順に1つを返す")
    func reasonOrder() {
        let offAndEmpty = Self.offering(metadata: ["onboarding_paywall": "off"], packages: [])
        #expect(OnboardingPaywallDecision.decide(offering: offAndEmpty, status: Self.entitled) == .skip(.entitled))
        #expect(OnboardingPaywallDecision.decide(offering: nil, status: Self.entitled) == .skip(.entitled))
        #expect(OnboardingPaywallDecision.decide(offering: offAndEmpty, status: .inactive) == .skip(.switchedOff))
    }

    @Test("名前は計測とダッシュボードの語に合わせる")
    func names() {
        #expect(OnboardingPaywallDecision.placement == "onboarding")
        #expect(OnboardingPaywallDecision.source == "onboarding")
        #expect(OnboardingPaywallDecision.metadataKey == "onboarding_paywall")
        #expect(OnboardingPaywallSkipReason.allCases.map(\.rawValue) == ["entitled", "switched_off", "nothing_to_sell"])
    }
}
