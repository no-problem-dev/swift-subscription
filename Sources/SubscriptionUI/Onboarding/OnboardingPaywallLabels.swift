import Foundation

/// The words that ``OnboardingPaywallStep`` puts on screen, so an app can localize them.
///
/// Only the words. Whether the × and "Continue for free" appear, and where, is not configurable:
/// both are always there, from the first frame.
public struct OnboardingPaywallLabels: Sendable {
    /// What VoiceOver reads for the × in the top-leading corner.
    public var close: String

    /// The button beneath the paywall that closes it without buying.
    ///
    /// Say that the app goes on for free. "Later" or "Not now" reads as a reminder to come, and
    /// is a different event (`via=later`).
    public var continueFree: String

    /// Creates a set of labels. English by default.
    ///
    /// - Parameters:
    ///   - close: What VoiceOver reads for the ×.
    ///   - continueFree: The button that closes the paywall without buying.
    public init(close: String = "Close", continueFree: String = "Continue for free") {
        self.close = close
        self.continueFree = continueFree
    }

    /// The labels in Japanese.
    public static let japanese = OnboardingPaywallLabels(close: "閉じる", continueFree: "無料のまま続ける")
}
