import SwiftUI
import Testing
import SubscriptionOnboarding

// This file imports `SubscriptionOnboarding` only: it compiles when that one import is enough to
// name `PackageDuration` and to give the step the app's button styles.

@MainActor
struct OnboardingPaywallImportTests {
    private struct CircleStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.background(.white, in: Circle())
        }
    }

    @Test
    func packageDurationIsNamedThroughTheOnboardingProduct() {
        let plan: PackageDuration = .annual
        #expect(plan.rawValue == "annual")
    }

    @Test
    func theStepTakesTheAppsButtonStyles() {
        let step = OnboardingPaywallStep(onFinish: { _ in }) { context in
            Button("Buy") { context.purchased(PackageDuration.annual) }
        }
        .onboardingPaywallCloseButtonStyle(CircleStyle())
        .onboardingPaywallRestoreButtonStyle(.bordered)
        .onboardingPaywallContinueFreeButtonStyle(.borderedProminent)
        _ = step
    }
}
