import Foundation
import RevenueCat

/// Maps the RevenueCat SDK onto ``SubscriptionRepository``.
///
/// The SDK is configured once, from init, against a process-global `Purchases.shared`.
/// Nothing below this line can be exercised on a simulator launched by `simctl`: a
/// `.storekit` configuration file is only applied by an Xcode IDE Run, and a `simctl`
/// launch falls through to the real App Store sandbox instead. The pure functions under
/// "Testable Core" exist because of that — they are the part that can be tested at all.
final class RevenueCatRepository: SubscriptionRepository {
    private let configuration: SubscriptionConfiguration
    private let isConfigured: Bool

    init(configuration: SubscriptionConfiguration) {
        self.configuration = configuration
        self.isConfigured = Self.configureRevenueCat(
            apiKey: configuration.apiKey,
            allowsTestStoreInReleaseBuilds: configuration.allowsTestStoreInReleaseBuilds
        )
    }

    // MARK: - Configuration

    private static func configureRevenueCat(apiKey: String, allowsTestStoreInReleaseBuilds: Bool) -> Bool {
        guard !apiKey.isEmpty else { return false }

        Purchases.configure(
            with: Configuration.Builder(withAPIKey: apiKey)
                .with(dangerousSettings: DangerousSettings(
                    autoSyncPurchases: true,
                    forceAllowTestStoreInReleaseBuilds: allowsTestStoreInReleaseBuilds
                ))
                .build()
        )
        return true
    }

    // MARK: - SubscriptionRepository

    func checkSubscriptionStatus() async throws -> SubscriptionStatus {
        guard isConfigured else {
            throw SubscriptionError.notConfigured
        }

        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            return extractSubscriptionStatus(from: customerInfo)
        } catch {
            throw SubscriptionError.networkError(error)
        }
    }

    func loadOffering(id: String?) async throws -> SubscriptionOffering? {
        guard isConfigured else {
            throw SubscriptionError.notConfigured
        }

        let offering: Offering?
        do {
            offering = Self.offering(id, in: try await Purchases.shared.offerings())
        } catch {
            throw SubscriptionError.networkError(error)
        }
        guard let offering else { return nil }

        // Asked only for packages that carry an introductory offer: eligibility is a store
        // round trip, and the answer means nothing for a product without one.
        let withOffer = offering.availablePackages.filter { $0.storeProduct.introductoryDiscount != nil }
        let eligibility = withOffer.isEmpty
            ? [:]
            : await Purchases.shared.checkTrialOrIntroDiscountEligibility(packages: withOffer)

        let packages = offering.availablePackages.map { package in
            SubscriptionPackage(
                id: package.identifier,
                productId: package.storeProduct.productIdentifier,
                title: package.storeProduct.localizedTitle,
                description: package.storeProduct.localizedDescription,
                price: package.storeProduct.localizedPriceString,
                pricePerMonth: calculateMonthlyPrice(for: package),
                duration: convertDuration(for: package),
                introductoryOffer: package.storeProduct.introductoryDiscount.map { discount in
                    Self.introductoryOffer(
                        paymentMode: discount.paymentMode,
                        period: discount.subscriptionPeriod,
                        periodCount: discount.numberOfPeriods,
                        price: discount.localizedPriceString,
                        eligibility: eligibility[package]?.status
                    )
                }
            )
        }

        return SubscriptionOffering(id: offering.identifier, packages: packages)
    }

    func purchase(packageId: String, offeringId: String?) async throws -> SubscriptionStatus {
        guard isConfigured else {
            throw SubscriptionError.notConfigured
        }

        do {
            let offerings = try await Purchases.shared.offerings()
            guard let offering = Self.offering(offeringId, in: offerings),
                  let package = offering.availablePackages.first(where: { $0.identifier == packageId }) else {
                throw SubscriptionError.packageNotFound(packageId)
            }

            let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)

            if userCancelled {
                throw SubscriptionError.purchaseCancelled
            }

            return extractSubscriptionStatus(from: customerInfo)
        } catch let error as SubscriptionError {
            throw error
        } catch {
            throw Self.purchaseError(error)
        }
    }

    func restorePurchases() async throws -> SubscriptionStatus {
        guard isConfigured else {
            throw SubscriptionError.notConfigured
        }

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            return extractSubscriptionStatus(from: customerInfo)
        } catch {
            throw SubscriptionError.restoreFailed(error)
        }
    }

    func syncUser(userId: String) async throws {
        guard isConfigured else {
            throw SubscriptionError.notConfigured
        }

        do {
            _ = try await Purchases.shared.logIn(userId)

            // Runs after login on purpose: attributes set before the identity swap would be
            // written against the anonymous identity and lost.
            if let setter = configuration.customAttributesSetter {
                await setter(userId)
            }
        } catch {
            throw SubscriptionError.userSyncFailed(error)
        }
    }

    func clearUser() async throws {
        guard isConfigured else {
            throw SubscriptionError.notConfigured
        }

        guard !Purchases.shared.isAnonymous else { return }

        do {
            _ = try await Purchases.shared.logOut()
        } catch {
            throw SubscriptionError.userSyncFailed(error)
        }
    }

    func observeSubscriptionChanges() -> AsyncStream<SubscriptionStatus> {
        AsyncStream { continuation in
            guard isConfigured else {
                continuation.finish()
                return
            }

            let task = Task {
                for await customerInfo in Purchases.shared.customerInfoStream {
                    continuation.yield(extractSubscriptionStatus(from: customerInfo))
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Private Helpers

    private func extractSubscriptionStatus(from customerInfo: CustomerInfo) -> SubscriptionStatus {
        let entitlements = customerInfo.entitlements.all.mapValues { entitlement in
            EntitlementSnapshot(
                isActive: entitlement.isActive,
                productIdentifier: entitlement.productIdentifier,
                expirationDate: entitlement.expirationDate
            )
        }
        return Self.subscriptionStatus(from: entitlements, entitlementId: configuration.entitlementId)
    }

    private func calculateMonthlyPrice(for package: Package) -> String? {
        Self.monthlyPriceString(
            duration: convertDuration(for: package),
            price: package.storeProduct.price,
            locale: package.storeProduct.priceFormatter?.locale
        )
    }

    private func convertDuration(for package: Package) -> PackageDuration {
        Self.packageDuration(for: package.packageType, period: package.storeProduct.subscriptionPeriod)
    }

    // MARK: - Testable Core

    /// The offering with this identifier, or the current one for `nil`.
    ///
    /// An identifier that is not in the dashboard finds nothing. It never falls back to the
    /// current offering: a paywall asked for one set of products and would be selling another.
    static func offering(_ identifier: String?, in offerings: Offerings) -> Offering? {
        guard let identifier else { return offerings.current }
        return offerings.all[identifier]
    }

    /// What a purchase that threw means. A deferred purchase — Ask to Buy — is not a failure.
    static func purchaseError(_ error: any Error) -> SubscriptionError {
        if let code = error as? ErrorCode, code == .paymentPendingError {
            return .purchasePending
        }
        return .purchaseFailed(error)
    }

    /// Maps the store's description of an introductory discount onto ``IntroductoryOffer``.
    ///
    /// Anything the store did not answer with "eligible" — including no answer at all — is
    /// reported as ``IntroductoryOffer/Eligibility/unknown`` or ``IntroductoryOffer/Eligibility/ineligible``,
    /// so a paywall that follows the eligibility never promises a trial the store then refuses.
    static func introductoryOffer(
        paymentMode: StoreProductDiscount.PaymentMode,
        period: RevenueCat.SubscriptionPeriod,
        periodCount: Int,
        price: String,
        eligibility: IntroEligibilityStatus?
    ) -> IntroductoryOffer {
        IntroductoryOffer(
            paymentMode: introductoryPaymentMode(paymentMode),
            period: IntroductoryOffer.Period(value: period.value, unit: periodUnit(period.unit)),
            periodCount: periodCount,
            price: price,
            eligibility: introductoryEligibility(eligibility)
        )
    }

    static func introductoryPaymentMode(_ mode: StoreProductDiscount.PaymentMode) -> IntroductoryOffer.PaymentMode {
        switch mode {
        case .freeTrial: return .freeTrial
        case .payAsYouGo: return .payAsYouGo
        case .payUpFront: return .payUpFront
        }
    }

    static func periodUnit(_ unit: RevenueCat.SubscriptionPeriod.Unit) -> IntroductoryOffer.Period.Unit {
        switch unit {
        case .day: return .day
        case .week: return .week
        case .month: return .month
        case .year: return .year
        }
    }

    static func introductoryEligibility(_ status: IntroEligibilityStatus?) -> IntroductoryOffer.Eligibility {
        switch status {
        case .eligible: return .eligible
        case .ineligible, .noIntroOfferExists: return .ineligible
        case .unknown, nil: return .unknown
        }
    }

    /// The fields of a RevenueCat entitlement this package actually reads.
    ///
    /// `CustomerInfo` cannot be constructed in a test, so the entitlement decision is taken
    /// against this instead.
    struct EntitlementSnapshot: Sendable, Equatable {
        let isActive: Bool
        let productIdentifier: String
        let expirationDate: Date?

        init(isActive: Bool, productIdentifier: String, expirationDate: Date?) {
            self.isActive = isActive
            self.productIdentifier = productIdentifier
            self.expirationDate = expirationDate
        }
    }

    /// Decides whether the customer is entitled, from a snapshot of all their entitlements.
    ///
    /// Fails closed in every ambiguous case: an unknown identifier, an expired entitlement, or
    /// a different entitlement being active all resolve to `.inactive`. Only the entitlement
    /// named by `entitlementId` can grant access, so a customer subscribed to some other
    /// product of the same app is not entitled here.
    static func subscriptionStatus(
        from entitlements: [String: EntitlementSnapshot],
        entitlementId: String
    ) -> SubscriptionStatus {
        guard let entitlement = entitlements[entitlementId],
              entitlement.isActive else {
            return .inactive
        }

        return SubscriptionStatus(
            isActive: true,
            activeEntitlementId: entitlementId,
            activePackageId: entitlement.productIdentifier,
            expirationDate: entitlement.expirationDate
        )
    }

    /// Formats an annual price as its per-month equivalent, for the "only ¥500/month" line.
    ///
    /// Returns `nil` for anything but an annual package, since a monthly equivalent of a
    /// monthly price is just the price. The result is a derived marketing figure, not an
    /// amount anyone is charged, and it is rounded by the currency's own formatter.
    static func monthlyPriceString(
        packageType: PackageType,
        price: Decimal,
        locale: Locale?
    ) -> String? {
        monthlyPriceString(duration: packageDuration(for: packageType), price: price, locale: locale)
    }

    static func monthlyPriceString(
        duration: PackageDuration,
        price: Decimal,
        locale: Locale?
    ) -> String? {
        guard duration == .annual else { return nil }

        let monthlyPrice = price / 12

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale

        return formatter.string(from: monthlyPrice as NSDecimalNumber)
    }

    /// How long a package lasts. A package with a custom identifier in the dashboard has the
    /// type `.custom`, so its length is read from the product's subscription period instead.
    static func packageDuration(for packageType: PackageType, period: SubscriptionPeriod? = nil) -> PackageDuration {
        switch packageType {
        case .monthly:
            return .monthly
        case .annual:
            return .annual
        case .lifetime:
            return .lifetime
        case .custom, .unknown:
            return period.map(packageDuration(for:)) ?? .unknown
        default:
            return .unknown
        }
    }

    static func packageDuration(for period: SubscriptionPeriod) -> PackageDuration {
        switch (period.unit, period.value) {
        case (.month, 1):
            return .monthly
        case (.year, 1), (.month, 12):
            return .annual
        default:
            return .unknown
        }
    }
}
