import SwiftUI

/// The restore button and the two legal links, which every paywall selling a subscription
/// needs and which are the easiest three things to leave out.
///
/// ``PaywallView`` puts one of these at the bottom. It is public so that an app drawing its own
/// paywall can still take the part that is not a design decision.
public struct PaywallLegalFooter: View {
    private let labels: PaywallLabels
    private let links: PaywallLegalLinks
    private let isDisabled: Bool
    private let restore: @MainActor () async -> Void

    /// Creates a footer.
    ///
    /// - Parameters:
    ///   - labels: The words this package puts on screen.
    ///   - links: The terms of use and the privacy policy. Both are required.
    ///   - isDisabled: Whether the restore button is unavailable, as it is while a purchase is
    ///     in flight.
    ///   - restore: What to run when restore is tapped.
    public init(
        labels: PaywallLabels = PaywallLabels(),
        links: PaywallLegalLinks,
        isDisabled: Bool = false,
        restore: @escaping @MainActor () async -> Void
    ) {
        self.labels = labels
        self.links = links
        self.isDisabled = isDisabled
        self.restore = restore
    }

    public var body: some View {
        HStack(spacing: 12) {
            Button(labels.restore) {
                Task { await restore() }
            }
            .disabled(isDisabled)

            Divider().frame(height: 12)

            Link(labels.terms, destination: links.terms)

            Divider().frame(height: 12)

            Link(labels.privacy, destination: links.privacy)
        }
        .font(.footnote)
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
    }
}

#Preview("Legal footer") {
    PaywallLegalFooter(
        links: PaywallLegalLinks(
            terms: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!,
            privacy: URL(string: "https://example.com/privacy")!
        ),
        restore: {}
    )
    .padding()
}
