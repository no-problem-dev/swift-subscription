import SwiftUI
import Subscription

/// The last step of onboarding: the app's own paywall, with the ways out that every app must have.
///
/// The paywall is the app's — its pages, plans, copy and look (this package draws none of it).
/// The step owns what must not differ between apps:
///
/// - **a × in the top-leading corner**, there from the first frame, never delayed or faded
/// - **"Continue for free" beneath the paywall**, an ordinary button, always shown
/// - **one exit.** Closing with the ×, continuing for free, buying and restoring all end in
///   `onFinish`, exactly once, so onboarding always reaches the screen it promised
/// - **`source=onboarding`** on every event, with one `pw_id` per presentation
///
/// None of these has a parameter. An app that wants the × elsewhere, or no way to continue for
/// free, is asking for something App Store Review and the studio's rules both say no to.
///
/// ```swift
/// OnboardingPaywallStep(
///     labels: .japanese,
///     onEvent: { event in analytics.send(event.name, event.parameters) },
///     onFinish: { exit in
///         router.showHome(askForNotifications: exit.isEntitled)
///     }
/// ) { context in
///     MyPaywall(
///         offering: offering,
///         source: context.source,
///         paywallId: context.paywallId,
///         onWorking: context.setWorking,
///         onPurchased: context.purchased,
///         onRestored: context.restored
///     )
/// }
/// ```
///
/// Whether the step is shown at all is `OnboardingPaywallDecision`'s call: decide before
/// onboarding starts, and leave the step out when it says skip.
///
/// The step stays put while it is on screen: presented as a sheet, it cannot be swiped away, so the
/// × and "Continue for free" are the only ways out and each one is counted.
public struct OnboardingPaywallStep<Paywall: View>: View {
    private let labels: OnboardingPaywallLabels
    private let onEvent: @MainActor (OnboardingPaywallEvent) -> Void
    private let onFinish: @MainActor (OnboardingPaywallExit) -> Void
    private let paywall: @MainActor (OnboardingPaywallContext) -> Paywall

    @State private var paywallId = OnboardingPaywallEvent.makePaywallId()
    @State private var shownAt: Date?
    @State private var hasFinished = false
    @State private var isWorking = false

    /// Creates the step.
    ///
    /// - Parameters:
    ///   - labels: The words on the × and on "Continue for free". English by default;
    ///     ``OnboardingPaywallLabels/japanese`` for Japanese.
    ///   - onEvent: Receives `paywall_shown` when the step appears and `paywall_closed` when the
    ///     customer leaves it, to send to the app's analytics.
    ///   - onFinish: Run once, however the customer leaves: the place to go on to the screen
    ///     onboarding promised.
    ///   - paywall: Builds the app's paywall from the context it reports a purchase or a restore to.
    public init(
        labels: OnboardingPaywallLabels = OnboardingPaywallLabels(),
        onEvent: @escaping @MainActor (OnboardingPaywallEvent) -> Void = { _ in },
        onFinish: @escaping @MainActor (OnboardingPaywallExit) -> Void,
        @ViewBuilder paywall: @escaping @MainActor (OnboardingPaywallContext) -> Paywall
    ) {
        self.labels = labels
        self.onEvent = onEvent
        self.onFinish = onFinish
        self.paywall = paywall
    }

    public var body: some View {
        paywall(context)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack(spacing: 0) {
                    closeButton
                    Spacer(minLength: 0)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                continueFreeButton
            }
            .interactiveDismissDisabled()
            .onAppear { recordShown() }
    }

    private var context: OnboardingPaywallContext {
        OnboardingPaywallContext(
            paywallId: paywallId,
            finish: { exit in finish(exit) },
            working: { working in isWorking = working }
        )
    }

    private var closeButton: some View {
        Button {
            finish(.closeButton)
        } label: {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(labels.close)
        .disabled(isWorking || hasFinished)
        .padding(.leading, 8)
    }

    private var continueFreeButton: some View {
        Button {
            finish(.continueFree)
        } label: {
            Text(labels.continueFree)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .disabled(isWorking || hasFinished)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private func recordShown() {
        guard shownAt == nil else { return }
        shownAt = Date()
        onEvent(.shown(paywallId: paywallId))
    }

    private func finish(_ exit: OnboardingPaywallExit) {
        guard !hasFinished else { return }
        hasFinished = true
        isWorking = false
        let openSeconds = OnboardingPaywallEvent.openSeconds(from: shownAt, to: Date())
        onEvent(.closed(paywallId: paywallId, exit: exit, openSeconds: openSeconds))
        onFinish(exit)
    }
}

#Preview("Onboarding paywall") {
    OnboardingPaywallStep(labels: .japanese, onFinish: { _ in }) { context in
        VStack(spacing: 16) {
            Image(systemName: "sparkles").font(.system(size: 72))
            Text("Everything, unlocked").font(.largeTitle.bold())
            Button("Buy") { context.purchased(SubscriptionOffering.preview.packages[0]) }
                .buttonStyle(.borderedProminent)
        }
    }
}
