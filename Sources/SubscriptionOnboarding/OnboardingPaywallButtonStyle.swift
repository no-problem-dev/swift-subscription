import SwiftUI

// The look of the step's three buttons is the app's. Where they are and whether they are there is
// not: these modifiers change only the style a button is drawn with, never its place, its words,
// its accessibility identifier or when it is enabled.

extension View {
    /// Draws the × of ``OnboardingPaywallStep`` with the app's button style.
    ///
    /// The × stays in the top-leading corner from the first frame. The style receives the
    /// `xmark` symbol in a 44-point square as its label, so it can put the symbol in a circle
    /// without making the button smaller to tap:
    ///
    /// ```swift
    /// struct CircleCloseStyle: ButtonStyle {
    ///     func makeBody(configuration: Configuration) -> some View {
    ///         configuration.label
    ///             .foregroundStyle(.black)
    ///             .background(.white, in: Circle().inset(by: 6))
    ///             .opacity(configuration.isPressed ? 0.6 : 1)
    ///     }
    /// }
    ///
    /// OnboardingPaywallStep(onFinish: { _ in }) { context in MyPaywall(context) }
    ///     .onboardingPaywallCloseButtonStyle(CircleCloseStyle())
    /// ```
    ///
    /// Without it the × is drawn with `.plain`.
    public func onboardingPaywallCloseButtonStyle<S: ButtonStyle>(_ style: S) -> some View {
        environment(\.onboardingPaywallCloseButtonStyle, OnboardingPaywallButtonStyle(style))
    }

    /// The same, with a primitive style such as `.bordered` or `.borderedProminent`.
    public func onboardingPaywallCloseButtonStyle<S: PrimitiveButtonStyle>(_ style: S) -> some View {
        environment(\.onboardingPaywallCloseButtonStyle, OnboardingPaywallButtonStyle(style))
    }

    /// Draws "Restore Purchases" of ``OnboardingPaywallStep`` with the app's button style.
    ///
    /// It stays at the trailing end of the ×'s row, shown only when the step is given `restore`.
    /// The label is the text of ``OnboardingPaywallLabels/restore`` at least 44 points tall.
    /// Without it the button is drawn with `.plain`.
    public func onboardingPaywallRestoreButtonStyle<S: ButtonStyle>(_ style: S) -> some View {
        environment(\.onboardingPaywallRestoreButtonStyle, OnboardingPaywallButtonStyle(style))
    }

    /// The same, with a primitive style such as `.bordered` or `.borderedProminent`.
    public func onboardingPaywallRestoreButtonStyle<S: PrimitiveButtonStyle>(_ style: S) -> some View {
        environment(\.onboardingPaywallRestoreButtonStyle, OnboardingPaywallButtonStyle(style))
    }

    /// Draws "Continue for free" of ``OnboardingPaywallStep`` with the app's button style.
    ///
    /// It stays beneath the paywall, always shown. The label is the text of
    /// ``OnboardingPaywallLabels/continueFree`` across the full width, at least 44 points tall.
    /// Without it the button takes the button style around the step, as before.
    public func onboardingPaywallContinueFreeButtonStyle<S: ButtonStyle>(_ style: S) -> some View {
        environment(\.onboardingPaywallContinueFreeButtonStyle, OnboardingPaywallButtonStyle(style))
    }

    /// The same, with a primitive style such as `.bordered` or `.borderedProminent`.
    public func onboardingPaywallContinueFreeButtonStyle<S: PrimitiveButtonStyle>(_ style: S) -> some View {
        environment(\.onboardingPaywallContinueFreeButtonStyle, OnboardingPaywallButtonStyle(style))
    }
}

/// A button style the app handed in, kept without its type so the step's type does not change.
struct OnboardingPaywallButtonStyle {
    private let apply: @MainActor (AnyView) -> AnyView

    @MainActor
    init<S: ButtonStyle>(_ style: S) {
        apply = { button in AnyView(button.buttonStyle(style)) }
    }

    @MainActor
    init<S: PrimitiveButtonStyle>(_ style: S) {
        apply = { button in AnyView(button.buttonStyle(style)) }
    }

    @MainActor
    func callAsFunction(_ button: some View) -> AnyView {
        apply(AnyView(button))
    }
}

extension EnvironmentValues {
    @Entry var onboardingPaywallCloseButtonStyle: OnboardingPaywallButtonStyle?
    @Entry var onboardingPaywallRestoreButtonStyle: OnboardingPaywallButtonStyle?
    @Entry var onboardingPaywallContinueFreeButtonStyle: OnboardingPaywallButtonStyle?
}

extension View {
    /// The app's style when it gave one, else `fallback`.
    @ViewBuilder
    func onboardingPaywallButtonStyle(_ style: OnboardingPaywallButtonStyle?, fallback: some PrimitiveButtonStyle) -> some View {
        if let style {
            style(self)
        } else {
            buttonStyle(fallback)
        }
    }

    /// The app's style when it gave one, else the style around the step.
    @ViewBuilder
    func onboardingPaywallButtonStyle(_ style: OnboardingPaywallButtonStyle?) -> some View {
        if let style {
            style(self)
        } else {
            self
        }
    }
}
