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
        self.isConfigured = Self.configureRevenueCat(apiKey: configuration.apiKey)
    }

    // MARK: - Configuration

    private static func configureRevenueCat(apiKey: String) -> Bool {
        guard !apiKey.isEmpty else {
            print("⚠️ RevenueCat API Key is empty")
            return false
        }

        Purchases.configure(withAPIKey: apiKey)
        print("✅ RevenueCat configured")
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

    func loadOfferings() async throws -> SubscriptionOffering? {
        guard isConfigured else {
            throw SubscriptionError.notConfigured
        }

        do {
            let offerings = try await Purchases.shared.offerings()
            guard let currentOffering = offerings.current else {
                return nil
            }

            let packages = currentOffering.availablePackages.map { package in
                SubscriptionPackage(
                    id: package.identifier,
                    title: package.storeProduct.localizedTitle,
                    description: package.storeProduct.localizedDescription,
                    price: package.storeProduct.localizedPriceString,
                    pricePerMonth: calculateMonthlyPrice(for: package),
                    duration: convertDuration(for: package.packageType)
                )
            }

            return SubscriptionOffering(id: currentOffering.identifier, packages: packages)
        } catch {
            throw SubscriptionError.networkError(error)
        }
    }

    func purchase(packageId: String) async throws -> SubscriptionStatus {
        guard isConfigured else {
            throw SubscriptionError.notConfigured
        }

        do {
            let offerings = try await Purchases.shared.offerings()
            guard let currentOffering = offerings.current,
                  let package = currentOffering.availablePackages.first(where: { $0.identifier == packageId }) else {
                throw SubscriptionError.packageNotFound(packageId)
            }

            let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)

            if userCancelled {
                throw SubscriptionError.purchaseCancelled
            }

            let status = extractSubscriptionStatus(from: customerInfo)
            if status.isActive {
                print("✅ Purchase successful")
            }
            return status
        } catch let error as SubscriptionError {
            throw error
        } catch {
            throw SubscriptionError.purchaseFailed(error)
        }
    }

    func restorePurchases() async throws -> SubscriptionStatus {
        guard isConfigured else {
            throw SubscriptionError.notConfigured
        }

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            let status = extractSubscriptionStatus(from: customerInfo)
            print("✅ Restore completed: \(status.isActive ? "Active subscription found" : "No active subscription")")
            return status
        } catch {
            throw SubscriptionError.restoreFailed(error)
        }
    }

    func syncUser(userId: String) async throws {
        guard isConfigured else {
            throw SubscriptionError.notConfigured
        }

        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(userId)

            // Runs after login on purpose: attributes set before the identity swap would be
            // written against the anonymous identity and lost.
            if let setter = configuration.customAttributesSetter {
                await setter(userId)
            }

            let status = extractSubscriptionStatus(from: customerInfo)
            print("✅ RevenueCat logged in: \(status.isActive ? "Active subscription" : "No subscription")")
        } catch {
            throw SubscriptionError.userSyncFailed(error)
        }
    }

    func clearUser() async throws {
        guard isConfigured else {
            throw SubscriptionError.notConfigured
        }

        do {
            _ = try await Purchases.shared.logOut()
            print("✅ RevenueCat logged out")
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
                    let status = extractSubscriptionStatus(from: customerInfo)
                    print("📱 Subscription status updated: \(status.isActive ? "Active" : "Inactive")")
                    continuation.yield(status)
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
            packageType: package.packageType,
            price: package.storeProduct.price,
            locale: package.storeProduct.priceFormatter?.locale
        )
    }

    private func convertDuration(for packageType: PackageType) -> PackageDuration {
        Self.packageDuration(for: packageType)
    }

    // MARK: - Testable Core

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
        guard packageType == .annual else { return nil }

        let monthlyPrice = price / 12

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale

        return formatter.string(from: monthlyPrice as NSDecimalNumber)
    }

    static func packageDuration(for packageType: PackageType) -> PackageDuration {
        switch packageType {
        case .monthly:
            return .monthly
        case .annual:
            return .annual
        case .lifetime:
            return .lifetime
        default:
            return .unknown
        }
    }
}
