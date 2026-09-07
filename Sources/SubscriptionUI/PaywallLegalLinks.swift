import Foundation

/// The two documents a paywall has to link to.
///
/// Both are required, and that is the point of the type. A paywall that sells a subscription
/// without a link to the terms and to the privacy policy is a 3.1.2 rejection, and the way to
/// make it hard to ship one is to leave no way to construct the paywall without them.
///
/// Apple's standard EULA is a valid answer for `terms` when the app does not have its own:
/// `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`.
public struct PaywallLegalLinks: Sendable {
    /// The terms of use, or Apple's standard EULA.
    public let terms: URL

    /// The privacy policy. The same URL App Store Connect has.
    public let privacy: URL

    /// Creates the pair.
    ///
    /// - Parameters:
    ///   - terms: The terms of use.
    ///   - privacy: The privacy policy.
    public init(terms: URL, privacy: URL) {
        self.terms = terms
        self.privacy = privacy
    }
}
