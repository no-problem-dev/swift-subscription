import SwiftUI
import Subscription

/// A paywall's skeleton: the app's pages on top, and beneath them the plans, the purchase
/// button, the restore button and the legal links.
///
/// The parts that are the same in every app are here; the parts that are not are the app's.
/// Nothing in this file chooses a colour, a typeface or a background, and the target depends on
/// no design system — the pages you pass are drawn exactly as you wrote them.
///
/// What it does insist on, because App Store Review does:
///
/// - the amount that will be charged is the most prominent price on screen (``PaywallPlanRow``)
/// - a restore button
/// - links to the terms of use and the privacy policy, which ``PaywallLegalLinks`` requires
/// - more than one page when you have more than one thing to say
///
/// ## Driving it from the environment
///
/// ```swift
/// PaywallView(
///     pages: [PaywallPage(id: "intro") { IntroArtwork() }],
///     links: PaywallLegalLinks(terms: termsURL, privacy: privacyURL),
///     onEntitled: { dismiss() },
///     onError: { presentedError = $0 }
/// )
/// ```
///
/// This form reads the `SubscriptionUseCase` out of the environment, loads the current
/// offering, puts the annual plan first, preselects it, and buys and restores through it. With
/// nothing injected it renders a configuration error rather than an empty screen, so a missed
/// injection is visible during development instead of at the till.
///
/// ## Driving it yourself
///
/// ``init(pages:packages:links:labels:purchase:restore:onError:)`` takes the plans and the two
/// actions directly, for an app that owns its own purchase flow and wants the structure without
/// the wiring.
public struct PaywallView: View {
    /// The plans and actions, when the caller supplies them rather than the environment.
    private struct Explicit {
        let packages: [SubscriptionPackage]
        let purchase: @MainActor (SubscriptionPackage) async throws -> Void
        let restore: @MainActor () async throws -> Void
    }

    @Environment(\.subscriptionUseCase) private var subscriptionUseCase

    private let pages: [PaywallPage]
    private let links: PaywallLegalLinks
    private let labels: PaywallLabels
    private let explicit: Explicit?
    private let onEntitled: (@MainActor () -> Void)?
    private let onError: (@MainActor (any Error) -> Void)?

    @State private var packages: [SubscriptionPackage] = []
    @State private var recommendedPackageId: String?
    @State private var selectedPackageId: String?
    @State private var isWorking = false

    /// Creates a paywall that sells through the use case in the environment.
    ///
    /// - Parameters:
    ///   - pages: The sales content, one entry per page. Pass more than one to page through.
    ///   - links: The terms of use and the privacy policy.
    ///   - labels: The words this package puts on screen. English by default.
    ///   - onEntitled: Run when a purchase or a restore leaves the customer entitled — the
    ///     place to dismiss the paywall.
    ///   - onError: Run when a purchase or a restore fails. A cancelled purchase does not
    ///     arrive here: dismissing the sheet is an ordinary outcome, not a failure to report.
    public init(
        pages: [PaywallPage],
        links: PaywallLegalLinks,
        labels: PaywallLabels = PaywallLabels(),
        onEntitled: (@MainActor () -> Void)? = nil,
        onError: (@MainActor (any Error) -> Void)? = nil
    ) {
        self.pages = pages
        self.links = links
        self.labels = labels
        self.explicit = nil
        self.onEntitled = onEntitled
        self.onError = onError
    }

    /// Creates a paywall over plans and actions you supply.
    ///
    /// It never reads the environment, so it works with nothing injected.
    ///
    /// - Parameters:
    ///   - pages: The sales content, one entry per page.
    ///   - packages: The plans, in the order to show them. The first is preselected.
    ///   - links: The terms of use and the privacy policy.
    ///   - labels: The words this package puts on screen. English by default.
    ///   - purchase: Run with the selected plan when the purchase button is tapped.
    ///   - restore: Run when restore is tapped.
    ///   - onError: Run when either throws, except for
    ///     `SubscriptionError.purchaseCancelled`.
    public init(
        pages: [PaywallPage],
        packages: [SubscriptionPackage],
        links: PaywallLegalLinks,
        labels: PaywallLabels = PaywallLabels(),
        purchase: @escaping @MainActor (SubscriptionPackage) async throws -> Void,
        restore: @escaping @MainActor () async throws -> Void,
        onError: (@MainActor (any Error) -> Void)? = nil
    ) {
        self.pages = pages
        self.links = links
        self.labels = labels
        self.explicit = Explicit(packages: packages, purchase: purchase, restore: restore)
        self.onEntitled = nil
        self.onError = onError
    }

    public var body: some View {
        Group {
            if explicit == nil && subscriptionUseCase == nil {
                PaywallConfigurationErrorView()
            } else {
                content
            }
        }
        .task { await load() }
    }

    private var content: some View {
        VStack(spacing: 0) {
            PaywallPageStrip(pages: pages)

            VStack(spacing: 16) {
                PaywallPlanPicker(
                    packages: packages,
                    selection: $selectedPackageId,
                    recommendedPackageId: recommendedPackageId,
                    labels: labels
                )

                purchaseButton

                PaywallLegalFooter(
                    labels: labels,
                    links: links,
                    isDisabled: isWorking,
                    restore: { await restore() }
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
    }

    /// A verb, and no amount. The row above already says what will be charged, and a second
    /// price here — the monthly equivalent, most often — is the 3.1.2(c) rejection.
    private var purchaseButton: some View {
        Button {
            Task { await purchase() }
        } label: {
            Text(labels.purchase)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .opacity(isWorking ? 0 : 1)
                .overlay { if isWorking { ProgressView() } }
        }
        .buttonStyle(.borderedProminent)
        .disabled(selectedPackage == nil || isWorking)
    }

    private var selectedPackage: SubscriptionPackage? {
        packages.first { $0.id == selectedPackageId }
    }

    // MARK: - Actions

    private func load() async {
        if let explicit {
            packages = explicit.packages
            recommendedPackageId = PaywallPlanOrder.recommended(in: explicit.packages)?.id
            selectedPackageId = selectedPackageId ?? explicit.packages.first?.id
            return
        }

        guard let subscriptionUseCase else { return }

        do {
            let offering = try await subscriptionUseCase.loadOfferings()
            let ordered = PaywallPlanOrder.annualFirst(offering?.packages ?? [])
            let recommended = PaywallPlanOrder.recommended(in: ordered)

            packages = ordered
            recommendedPackageId = recommended?.id
            selectedPackageId = selectedPackageId ?? recommended?.id
        } catch {
            report(error)
        }
    }

    private func purchase() async {
        guard let package = selectedPackage else { return }

        isWorking = true
        defer { isWorking = false }

        do {
            if let explicit {
                try await explicit.purchase(package)
            } else if let subscriptionUseCase {
                let status = try await subscriptionUseCase.purchase(packageId: package.id)
                if status.isActive { onEntitled?() }
            }
        } catch {
            report(error)
        }
    }

    private func restore() async {
        isWorking = true
        defer { isWorking = false }

        do {
            if let explicit {
                try await explicit.restore()
            } else if let subscriptionUseCase {
                // Returning normally is not evidence of an entitlement: a restore that finds
                // nothing succeeds and reports `.inactive`. Branching on the absence of an
                // error would tell someone who never subscribed that they had been restored.
                let status = try await subscriptionUseCase.restorePurchases()
                if status.isActive { onEntitled?() }
            }
        } catch {
            report(error)
        }
    }

    private func report(_ error: any Error) {
        // A dismissed purchase sheet is a normal outcome, not something to put in front of
        // someone as a failure.
        if case SubscriptionError.purchaseCancelled = error { return }
        onError?(error)
    }
}

// MARK: - Pages

/// The paged region. One page is shown plainly; several are paged through with an index.
private struct PaywallPageStrip: View {
    let pages: [PaywallPage]

    @State private var current: String?

    var body: some View {
        #if os(iOS) || os(tvOS)
        TabView(selection: $current) {
            ForEach(pages) { page in
                page.content.tag(Optional(page.id))
            }
        }
        .tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .always : .never))
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        #else
        // No page style outside iOS. Scrolling through the same content keeps every page
        // reachable rather than dropping all but the first.
        ScrollView {
            VStack(spacing: 24) {
                ForEach(pages) { $0.content }
            }
            .padding(.vertical, 24)
        }
        #endif
    }
}

// MARK: - Missing injection

private struct PaywallConfigurationErrorView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.red)
            Text("Subscription configuration error")
                .font(.title)
            Text("No SubscriptionUseCase is set in the environment")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview("Paywall") {
    PaywallView(
        pages: [
            PaywallPage(id: "focus") {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles").font(.system(size: 72))
                    Text("Everything, unlocked").font(.largeTitle.bold())
                }
            },
            PaywallPage(id: "sync") {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 72))
                    Text("On every device").font(.largeTitle.bold())
                }
            }
        ],
        links: .preview
    )
    .subscriptionUseCase(PreviewSubscriptionUseCase())
}
