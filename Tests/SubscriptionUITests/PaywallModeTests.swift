import Testing
import SubscriptionUI

@Suite("どちらのペイウォールを出すか")
struct PaywallModeTests {
    private static let lookups: [PaywallOfferingLookup] = [
        .hasPaywall, .noPaywall, .offeringMissing, .unavailable
    ]

    @Test("自前を選んだら、RevenueCat の答えによらず自前", arguments: lookups)
    func customAlwaysCustom(_ lookup: PaywallOfferingLookup) {
        #expect(PaywallMode.custom.choice(for: lookup) == .custom)
    }

    @Test("RevenueCat を選んだら、offering があれば RevenueCat を出す", arguments: [
        PaywallOfferingLookup.hasPaywall, .noPaywall
    ])
    func revenueCatWhenOfferingExists(_ lookup: PaywallOfferingLookup) {
        #expect(PaywallMode.revenueCat.choice(for: lookup) == .revenueCat)
        #expect(PaywallMode.revenueCat(offering: "summer").choice(for: lookup) == .revenueCat)
    }

    @Test("RevenueCat を選んでも、offering が無いか読み込めなければ自前に戻る", arguments: [
        PaywallOfferingLookup.offeringMissing, .unavailable
    ])
    func revenueCatFallsBack(_ lookup: PaywallOfferingLookup) {
        #expect(PaywallMode.revenueCat.choice(for: lookup) == .custom)
        #expect(PaywallMode.revenueCat(offering: "summer").choice(for: lookup) == .custom)
    }

    @Test("自動では、offering にペイウォールが付いているときだけ RevenueCat")
    func automaticNeedsAPaywall() {
        #expect(PaywallMode.automatic.choice(for: .hasPaywall) == .revenueCat)
        #expect(PaywallMode.automatic(offering: "summer").choice(for: .hasPaywall) == .revenueCat)
    }

    @Test("自動では、ペイウォールが付いていない・offering が無い・読み込めないときは自前", arguments: [
        PaywallOfferingLookup.noPaywall, .offeringMissing, .unavailable
    ])
    func automaticFallsBack(_ lookup: PaywallOfferingLookup) {
        #expect(PaywallMode.automatic.choice(for: lookup) == .custom)
    }

    @Test("自前のときだけ RevenueCat に問い合わせない")
    func onlyCustomSkipsTheLookup() {
        #expect(!PaywallMode.custom.needsLookup)
        #expect(PaywallMode.revenueCat.needsLookup)
        #expect(PaywallMode.automatic(offering: "summer").needsLookup)
    }

    @Test("offering の指定が無ければ current を探す")
    func offeringIdentifier() {
        #expect(PaywallMode.custom.offeringIdentifier == nil)
        #expect(PaywallMode.revenueCat.offeringIdentifier == nil)
        #expect(PaywallMode.automatic.offeringIdentifier == nil)
        #expect(PaywallMode.revenueCat(offering: "summer").offeringIdentifier == "summer")
        #expect(PaywallMode.automatic(offering: "summer").offeringIdentifier == "summer")
    }

    private static let automaticByName = PaywallMode.automatic
    private static let revenueCatByName = PaywallMode.revenueCat

    @Test("型名から書いた PaywallMode.automatic と .revenueCat は current の offering")
    func shorthandsByTypeName() {
        #expect(Self.automaticByName == .automatic(offering: nil))
        #expect(Self.automaticByName.offeringIdentifier == nil)
        #expect(Self.automaticByName.choice(for: .noPaywall) == .custom)
        #expect(Self.revenueCatByName == .revenueCat(offering: nil))
        #expect(Self.revenueCatByName.offeringIdentifier == nil)
        #expect(Self.revenueCatByName.choice(for: .noPaywall) == .revenueCat)
    }

    @Test("型を明示した代入の .automatic と .revenueCat は current の offering")
    func shorthandsByContextualType() {
        let automatic: PaywallMode = .automatic
        let revenueCat: PaywallMode = .revenueCat
        #expect(automatic == .automatic(offering: nil))
        #expect(revenueCat == .revenueCat(offering: nil))
        #expect(automatic != revenueCat)
    }
}
