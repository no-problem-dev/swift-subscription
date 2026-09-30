import Foundation
import Subscription

public extension SubscriptionOffering {
    /// An offering with an annual and a monthly plan, for previews and paywall mock-ups.
    ///
    /// The prices are already formatted, exactly as the store's would be. None of these
    /// packages can be bought — the identifiers are invented.
    static var preview: SubscriptionOffering {
        SubscriptionOffering(
            id: "preview",
            packages: [
                SubscriptionPackage(
                    id: "annual",
                    title: "Annual",
                    description: "12 months",
                    price: "¥6,000",
                    pricePerMonth: "¥500",
                    duration: .annual,
                    introductoryOffer: IntroductoryOffer(
                        paymentMode: .freeTrial,
                        period: IntroductoryOffer.Period(value: 7, unit: .day),
                        price: "¥0",
                        eligibility: .eligible
                    )
                ),
                SubscriptionPackage(
                    id: "monthly",
                    title: "Monthly",
                    description: "1 month",
                    price: "¥800",
                    pricePerMonth: nil,
                    duration: .monthly
                )
            ]
        )
    }
}

public extension PaywallLegalLinks {
    /// Placeholder links for previews. Apple's standard EULA, and a privacy policy that does
    /// not exist.
    static var preview: PaywallLegalLinks {
        PaywallLegalLinks(
            terms: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!,
            privacy: URL(string: "https://example.com/privacy")!
        )
    }
}

/// A `SubscriptionUseCase` that answers from fixed values, for previews.
///
/// It reaches no store and no network, so a paywall preview renders its plans immediately.
/// Every purchase it is asked for succeeds without charging anyone.
public struct PreviewSubscriptionUseCase: SubscriptionUseCase {
    private let offering: SubscriptionOffering?
    private let status: SubscriptionStatus

    /// Creates a stub.
    ///
    /// - Parameters:
    ///   - offering: What ``loadOfferings()`` answers. `nil` previews the dashboard mistake of
    ///     marking no offering current, which leaves a paywall with nothing to sell.
    ///   - status: What every entitlement read answers.
    public init(
        offering: SubscriptionOffering? = .preview,
        status: SubscriptionStatus = .inactive
    ) {
        self.offering = offering
        self.status = status
    }

    public func observeSubscriptionStatus() -> AsyncStream<SubscriptionStatus> {
        let status = self.status
        return AsyncStream { continuation in
            continuation.yield(status)
            continuation.finish()
        }
    }

    public func getSubscriptionStatus() async -> SubscriptionStatus { status }

    public func checkSubscriptionStatus() async throws -> SubscriptionStatus { status }

    public func loadOfferings() async throws -> SubscriptionOffering? { offering }

    public func purchase(packageId: String) async throws -> SubscriptionStatus {
        SubscriptionStatus(isActive: true, activePackageId: packageId)
    }

    public func restorePurchases() async throws -> SubscriptionStatus { status }

    public func syncUser(userId: String) async throws {}

    public func clearUser() async throws {}
}
