import Foundation
import SubscriptionPlan
import Testing
@testable import SubscriptionOnboarding

@Suite("オンボーディングの最後のペイウォールの出口と計測")
struct OnboardingPaywallEventTests {
    @Test("閉じ方ごとの result と via は共通のカタログの値")
    func exitValues() {
        #expect(OnboardingPaywallExit.closeButton.result == "dismissed")
        #expect(OnboardingPaywallExit.closeButton.via == "close_button")
        #expect(OnboardingPaywallExit.continueFree.result == "dismissed")
        #expect(OnboardingPaywallExit.continueFree.via == "continue_free")
        #expect(OnboardingPaywallExit.purchased(.annual).result == "purchased")
        #expect(OnboardingPaywallExit.purchased(.annual).via == "auto")
        #expect(OnboardingPaywallExit.restored.result == "restored")
        #expect(OnboardingPaywallExit.restored.via == "auto")
    }

    @Test("買ったときだけ product を持つ。annual は yearly、知らない長さは無し")
    func product() {
        #expect(OnboardingPaywallExit.purchased(.annual).product == "yearly")
        #expect(OnboardingPaywallExit.purchased(.monthly).product == "monthly")
        #expect(OnboardingPaywallExit.purchased(.lifetime).product == "lifetime")
        #expect(OnboardingPaywallExit.purchased(.unknown).product == nil)
        #expect(OnboardingPaywallExit.restored.product == nil)
        #expect(OnboardingPaywallExit.closeButton.product == nil)
        #expect(OnboardingPaywallExit.continueFree.product == nil)
    }

    @Test("買った・復元したは購読して出る。閉じた2つは購読しないで出る")
    func entitled() {
        #expect(OnboardingPaywallExit.purchased(.monthly).isEntitled)
        #expect(OnboardingPaywallExit.restored.isEntitled)
        #expect(!OnboardingPaywallExit.closeButton.isEntitled)
        #expect(!OnboardingPaywallExit.continueFree.isEntitled)
    }

    @Test("paywall_shown は source=onboarding と pw_id だけ")
    func shownEvent() {
        let event = OnboardingPaywallEvent.shown(paywallId: "0a1b2c3d")
        #expect(event.name == "paywall_shown")
        #expect(event.source == "onboarding")
        #expect(event.paywallId == "0a1b2c3d")
        #expect(event.parameters == ["source": "onboarding", "pw_id": "0a1b2c3d"])
    }

    @Test("×で閉じた paywall_closed")
    func closedByButton() {
        let event = OnboardingPaywallEvent.closed(paywallId: "0a1b2c3d", exit: .closeButton, openSeconds: 12)
        #expect(event.name == "paywall_closed")
        #expect(event.parameters == [
            "source": "onboarding", "pw_id": "0a1b2c3d",
            "result": "dismissed", "via": "close_button", "open_s": "12"
        ])
    }

    @Test("買って閉じた paywall_closed は product を持つ")
    func closedByPurchase() {
        let event = OnboardingPaywallEvent.closed(paywallId: "0a1b2c3d", exit: .purchased(.annual), openSeconds: 40)
        #expect(event.parameters == [
            "source": "onboarding", "pw_id": "0a1b2c3d",
            "result": "purchased", "via": "auto", "open_s": "40", "product": "yearly"
        ])
    }

    @Test("pw_id は小文字の16進8桁で、毎回違う")
    func paywallId() {
        let ids = (0..<50).map { _ in OnboardingPaywallEvent.makePaywallId() }
        for id in ids {
            #expect(id.count == 8)
            #expect(id.allSatisfy { "0123456789abcdef".contains($0) })
        }
        #expect(Set(ids).count == ids.count)
    }

    @Test("open_s は切り捨ての秒。出ていない・時計が戻ったときは0")
    func openSeconds() {
        let shown = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(OnboardingPaywallEvent.openSeconds(from: shown, to: shown.addingTimeInterval(12.9)) == 12)
        #expect(OnboardingPaywallEvent.openSeconds(from: shown, to: shown) == 0)
        #expect(OnboardingPaywallEvent.openSeconds(from: shown, to: shown.addingTimeInterval(-5)) == 0)
        #expect(OnboardingPaywallEvent.openSeconds(from: nil, to: shown) == 0)
    }

    @Test("日本語の文言は「無料のまま続ける」と「購入を復元」")
    func japaneseLabels() {
        #expect(OnboardingPaywallLabels.japanese.continueFree == "無料のまま続ける")
        #expect(OnboardingPaywallLabels.japanese.close == "閉じる")
        #expect(OnboardingPaywallLabels.japanese.restore == "購入を復元")
        #expect(OnboardingPaywallLabels().restore == "Restore Purchases")
    }

    @Test("買わずに閉じた paywall_closed は、選んでいたプランを product に持つ")
    func closeCarriesSelectedPlan() {
        let byButton = OnboardingPaywallClose(paywallId: "0a1b2c3d", exit: .closeButton, openSeconds: 12, selectedPlan: .monthly)
        #expect(byButton.name == "paywall_closed")
        #expect(byButton.parameters == [
            "source": "onboarding", "pw_id": "0a1b2c3d",
            "result": "dismissed", "via": "close_button", "open_s": "12", "product": "monthly"
        ])
        let free = OnboardingPaywallClose(paywallId: "0a1b2c3d", exit: .continueFree, openSeconds: 3, selectedPlan: .annual)
        #expect(free.product == "yearly")
        #expect(free.event == .closed(paywallId: "0a1b2c3d", exit: .continueFree, openSeconds: 3))
        #expect(free.event.parameters["product"] == nil)
    }

    @Test("product は買ったプランが選んでいたプランに勝つ。復元・未報告・知らない長さは無し")
    func closeProductRules() {
        #expect(OnboardingPaywallClose(paywallId: "a", exit: .purchased(.annual), openSeconds: 1, selectedPlan: .monthly).product == "yearly")
        #expect(OnboardingPaywallClose(paywallId: "a", exit: .restored, openSeconds: 1, selectedPlan: .monthly).product == nil)
        #expect(OnboardingPaywallClose(paywallId: "a", exit: .closeButton, openSeconds: 1, selectedPlan: nil).product == nil)
        #expect(OnboardingPaywallClose(paywallId: "a", exit: .closeButton, openSeconds: 1, selectedPlan: .unknown).product == nil)
        #expect(OnboardingPaywallClose(paywallId: "a", exit: .restored, openSeconds: 1, selectedPlan: .monthly).parameters["product"] == nil)
    }

    @Test("context は期間だけで買った・選んだを段に渡す")
    @MainActor
    func contextTakesDurations() {
        var exits: [OnboardingPaywallExit] = []
        var selections: [PackageDuration?] = []
        let context = OnboardingPaywallContext(
            paywallId: "0a1b2c3d",
            finish: { exits.append($0) },
            working: { _ in },
            selection: { selections.append($0) }
        )
        context.select(.monthly)
        context.select(nil)
        context.purchased(.annual)
        #expect(selections == [.monthly, nil])
        #expect(exits == [.purchased(.annual)])
        #expect(context.source == "onboarding")
    }

    @Test("ボタンの識別子は決まった値で、互いに違う")
    func identifiers() {
        #expect(OnboardingPaywallIdentifier.close == "onboarding_paywall.close")
        #expect(OnboardingPaywallIdentifier.continueFree == "onboarding_paywall.continue_free")
        #expect(OnboardingPaywallIdentifier.restore == "onboarding_paywall.restore")
    }

    @Test("paywall_shown を数えるまでの時間は impression と同じ1秒")
    func impressionDwell() {
        #expect(OnboardingPaywallEvent.impressionDwell == .seconds(1))
    }
}
