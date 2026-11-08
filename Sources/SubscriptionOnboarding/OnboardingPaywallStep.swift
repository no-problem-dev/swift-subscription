import SwiftUI

/// The last step of onboarding: the app's own paywall, with the ways out that every app must have.
///
/// The paywall is the app's — its pages, plans, copy and look (this package draws none of it).
/// The step owns what must not differ between apps:
///
/// - **a × in the top-leading corner**, there from the first frame, never delayed or faded
/// - **"Restore Purchases" at the trailing end of the same row**, when the step is given `restore`
/// - **"Continue for free" beneath the paywall**, an ordinary button, always shown
/// - **one exit.** Closing with the ×, continuing for free, buying and restoring all end in
///   `onFinish`, exactly once, so onboarding always reaches the screen it promised
/// - **`source=onboarding`** on every event, with one `pw_id` per presentation
/// - **fixed accessibility identifiers** on its buttons (``OnboardingPaywallIdentifier``)
///
/// The look of those buttons is the app's: `onboardingPaywallCloseButtonStyle(_:)`,
/// `onboardingPaywallRestoreButtonStyle(_:)` and `onboardingPaywallContinueFreeButtonStyle(_:)` draw them with the app's
/// `ButtonStyle`, in the same places. None of the rules above has a parameter. An app that wants the × elsewhere, or no way to continue for
/// free, is asking for something App Store Review and the studio's rules both say no to.
///
/// ```swift
/// OnboardingPaywallStep(
///     labels: .japanese,
///     onClose: { close in analytics.send(close.name, close.parameters) },
///     onFinish: { exit in
///         router.showHome(askForNotifications: exit.isEntitled)
///     },
///     restore: { await store.restore() }   // true when it left the customer entitled
/// ) { context in
///     MyPaywall(
///         paywallId: context.paywallId,
///         onSelect: context.select,         // (PackageDuration?) -> Void
///         onWorking: context.setWorking,
///         onPurchased: context.purchased    // (PackageDuration) -> Void
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
    private let impression: OnboardingPaywallImpression
    private let onEvent: @MainActor (OnboardingPaywallEvent) -> Void
    private let onClose: @MainActor (OnboardingPaywallClose) -> Void
    private let onFinish: @MainActor (OnboardingPaywallExit) -> Void
    private let restore: (@MainActor () async -> Bool)?
    private let paywall: @MainActor (OnboardingPaywallContext) -> Paywall

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.onboardingPaywallCloseButtonStyle) private var closeButtonStyle
    @Environment(\.onboardingPaywallRestoreButtonStyle) private var restoreButtonStyle
    @Environment(\.onboardingPaywallContinueFreeButtonStyle) private var continueFreeButtonStyle
    @State private var paywallId = OnboardingPaywallEvent.makePaywallId()
    @State private var appearedAt: Date?
    @State private var hasSentShown = false
    @State private var hasFinished = false
    @State private var isWorking = false
    @State private var selectedPlan: PackageDuration?

    /// Creates the step.
    ///
    /// - Parameters:
    ///   - labels: The words on the ×, "Restore Purchases" and "Continue for free". English by
    ///     default; ``OnboardingPaywallLabels/japanese`` for Japanese.
    ///   - impression: Who sends `paywall_shown`. By default the step does, once the paywall has
    ///     been on screen for a second; ``OnboardingPaywallImpression/byApp`` leaves it to the app.
    ///   - onEvent: Receives `paywall_shown` (unless the app sends it) and `paywall_closed`, to send
    ///     to the app's analytics.
    ///   - onClose: Receives the same `paywall_closed` with the plan selected when the customer
    ///     left. Send this or the `.closed` from `onEvent`, not both.
    ///   - onFinish: Run once, however the customer leaves: the place to go on to the screen
    ///     onboarding promised.
    ///   - restore: Restores an earlier purchase and answers whether the customer is entitled now.
    ///     Given, the step draws "Restore Purchases" at the trailing end of the ×'s row, disables
    ///     the ways out while it runs, and ends with ``OnboardingPaywallExit/restored`` on `true`.
    ///     On `false` the step stays: tell the customer on the paywall that nothing was found.
    ///   - paywall: Builds the app's paywall from the context it reports to.
    public init(
        labels: OnboardingPaywallLabels = OnboardingPaywallLabels(),
        impression: OnboardingPaywallImpression = .afterDwell,
        onEvent: @escaping @MainActor (OnboardingPaywallEvent) -> Void = { _ in },
        onClose: @escaping @MainActor (OnboardingPaywallClose) -> Void = { _ in },
        onFinish: @escaping @MainActor (OnboardingPaywallExit) -> Void,
        restore: (@MainActor () async -> Bool)? = nil,
        @ViewBuilder paywall: @escaping @MainActor (OnboardingPaywallContext) -> Paywall
    ) {
        self.labels = labels
        self.impression = impression
        self.onEvent = onEvent
        self.onClose = onClose
        self.onFinish = onFinish
        self.restore = restore
        self.paywall = paywall
    }

    public var body: some View {
        paywall(context)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack(spacing: 0) {
                    closeButton
                    Spacer(minLength: 0)
                    if restore != nil { restoreButton }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                continueFreeButton
            }
            .interactiveDismissDisabled()
            .onAppear { recordAppeared() }
            .task(id: scenePhase == .active) { await sendShownAfterDwell() }
    }

    private var context: OnboardingPaywallContext {
        OnboardingPaywallContext(
            paywallId: paywallId,
            finish: { exit in finish(exit) },
            working: { working in isWorking = working },
            selection: { plan in selectedPlan = plan }
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
        .onboardingPaywallButtonStyle(closeButtonStyle, fallback: .plain)
        .accessibilityLabel(labels.close)
        .accessibilityIdentifier(OnboardingPaywallIdentifier.close)
        .disabled(isWorking || hasFinished)
        .padding(.leading, 8)
    }

    private var restoreButton: some View {
        Button {
            Task { await runRestore() }
        } label: {
            Text(labels.restore)
                .font(.footnote)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .onboardingPaywallButtonStyle(restoreButtonStyle, fallback: .plain)
        .accessibilityIdentifier(OnboardingPaywallIdentifier.restore)
        .disabled(isWorking || hasFinished)
        .padding(.trailing, 16)
    }

    private var continueFreeButton: some View {
        Button {
            finish(.continueFree)
        } label: {
            Text(labels.continueFree)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .onboardingPaywallButtonStyle(continueFreeButtonStyle)
        .accessibilityIdentifier(OnboardingPaywallIdentifier.continueFree)
        .disabled(isWorking || hasFinished)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private func recordAppeared() {
        guard appearedAt == nil else { return }
        appearedAt = Date()
    }

    private func sendShownAfterDwell() async {
        guard impression == .afterDwell, scenePhase == .active, !hasSentShown else { return }
        do {
            try await Task.sleep(for: OnboardingPaywallEvent.impressionDwell)
        } catch {
            return
        }
        guard !hasSentShown, !hasFinished else { return }
        hasSentShown = true
        onEvent(.shown(paywallId: paywallId))
    }

    private func runRestore() async {
        guard let restore, !isWorking, !hasFinished else { return }
        isWorking = true
        let isEntitled = await restore()
        isWorking = false
        if isEntitled { finish(.restored) }
    }

    private func finish(_ exit: OnboardingPaywallExit) {
        guard !hasFinished else { return }
        hasFinished = true
        isWorking = false
        let close = OnboardingPaywallClose(
            paywallId: paywallId,
            exit: exit,
            openSeconds: OnboardingPaywallEvent.openSeconds(from: appearedAt, to: Date()),
            selectedPlan: selectedPlan
        )
        onEvent(close.event)
        onClose(close)
        onFinish(exit)
    }
}

#Preview("Onboarding paywall") {
    OnboardingPaywallStep(labels: .japanese, onFinish: { _ in }, restore: { false }) { context in
        VStack(spacing: 16) {
            Image(systemName: "sparkles").font(.system(size: 72))
            Text("Everything, unlocked").font(.largeTitle.bold())
            Button("Buy") { context.purchased(.annual) }
                .buttonStyle(.borderedProminent)
        }
        .onAppear { context.select(.annual) }
    }
}
