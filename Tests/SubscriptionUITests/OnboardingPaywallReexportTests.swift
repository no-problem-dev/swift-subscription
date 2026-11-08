import SubscriptionCore
import Testing
@testable import SubscriptionOnboarding
import SubscriptionUI

@Suite("SubscriptionUI から見たオンボーディングの段")
struct OnboardingPaywallReexportTests {
    @Test("段の source は OnboardingPaywallDecision.source と同じ")
    func sourceMatchesDecision() {
        #expect(OnboardingPaywallEvent.onboardingSource == OnboardingPaywallDecision.source)
    }

    @Test("package で買ったと伝えても、期間で伝えたのと同じ出口になる")
    @MainActor
    func purchasedWithPackage() {
        var exits: [OnboardingPaywallExit] = []
        let context = OnboardingPaywallContext(paywallId: "0a1b2c3d", finish: { exits.append($0) }, working: { _ in }, selection: { _ in })
        let package = SubscriptionPackage(id: "$rc_monthly", title: "", description: "", price: "", pricePerMonth: nil, duration: .monthly)
        context.purchased(package)
        #expect(exits == [.purchased(.monthly)])
    }
}

// 3.7.0 の書き方がそのまま通ることを、型の検査で確かめる（呼ばれない）。
import SwiftUI

@MainActor
private func writtenFor370(close: @escaping @MainActor () -> Void) -> some View {
    OnboardingPaywallStep(labels: .japanese, onEvent: { event in
        guard case .closed(_, let exit, _) = event else { return }
        _ = exit.product
    }, onFinish: { _ in close() }) { context in
        PaywallFor370(onWorking: context.setWorking, onPurchased: context.purchased, onRestored: context.restored)
    }
}

private struct PaywallFor370: View {
    let onWorking: @MainActor (Bool) -> Void
    let onPurchased: @MainActor (SubscriptionPackage) -> Void
    let onRestored: @MainActor () -> Void
    var body: some View { EmptyView() }
}
