import Foundation
import Subscription
import Testing
@testable import SubscriptionUI

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

    @Test("日本語の文言は「無料のまま続ける」")
    func japaneseLabels() {
        #expect(OnboardingPaywallLabels.japanese.continueFree == "無料のまま続ける")
        #expect(OnboardingPaywallLabels.japanese.close == "閉じる")
    }
}
