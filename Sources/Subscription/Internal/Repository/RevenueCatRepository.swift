import Foundation
import RevenueCat

/// RevenueCatを使用したサブスクリプションリポジトリの実装
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

            // カスタム属性設定のコールバックがあれば実行
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
        guard let entitlement = customerInfo.entitlements[configuration.entitlementId],
              entitlement.isActive else {
            return .inactive
        }

        return SubscriptionStatus(
            isActive: true,
            activeEntitlementId: configuration.entitlementId,
            activePackageId: entitlement.productIdentifier,
            expirationDate: entitlement.expirationDate
        )
    }

    private func calculateMonthlyPrice(for package: Package) -> String? {
        guard package.packageType == .annual else { return nil }

        // 年額を12で割って月額換算
        let price = package.storeProduct.price
        let monthlyPrice = price / 12

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = package.storeProduct.priceFormatter?.locale

        return formatter.string(from: monthlyPrice as NSDecimalNumber)
    }

    private func convertDuration(for packageType: PackageType) -> PackageDuration {
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
