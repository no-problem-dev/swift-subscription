import Foundation

/// A failure raised by a subscription operation.
///
/// Only ``purchaseCancelled`` is an ordinary outcome; the rest are genuine failures. Match
/// that case before any generic error handling, because presenting it as an error tells a
/// customer that something broke when they simply changed their mind.
///
/// ## Example
/// ```swift
/// do {
///     let status = try await subscriptionUseCase.purchase(packageId: "annual")
/// } catch SubscriptionError.purchaseCancelled {
///     // Expected. Dismiss quietly.
/// } catch {
///     showAlert(message: error.localizedDescription)
/// }
/// ```
public enum SubscriptionError: Error, LocalizedError {
    /// The API key was empty at configuration, so no store call can succeed.
    ///
    /// A build or environment problem rather than something the customer can resolve, and it
    /// is raised by every operation until the key is supplied.
    case notConfigured

    /// The configuration was rejected. Never raised by this package.
    case invalidConfiguration(String)

    /// The store could not be reached while reading the entitlement or the products.
    ///
    /// Worth a retry. Access already granted should be left alone, since being offline is
    /// not evidence that a subscription ended.
    case networkError(Error)

    /// The customer dismissed the purchase sheet. Expected, and not an error to display.
    case purchaseCancelled

    /// The purchase failed to complete, wrapping the store's reason.
    ///
    /// Covers a declined payment and an interrupted transaction alike. The entitlement is
    /// unchanged, so nothing was charged for.
    case purchaseFailed(Error)

    /// The restore request was rejected by the store.
    ///
    /// Distinct from a successful restore that finds nothing, which returns `.inactive`
    /// rather than throwing.
    case restoreFailed(Error)

    /// No products were available. Never raised by this package; a missing offering is
    /// reported as `nil` from ``SubscriptionUseCase/loadOfferings()`` instead.
    case offeringsNotAvailable

    /// No package in the current offering has the requested identifier.
    ///
    /// Usually an App Store product identifier passed where the offering's package
    /// identifier was expected, or a paywall built against an offering that is no longer
    /// current.
    case packageNotFound(String)

    /// Attaching or detaching the billing identity failed, leaving purchases attributed to
    /// the previous identity.
    case userSyncFailed(Error)

    /// An unclassified failure. Never raised by this package.
    case unknown(Error)

    /// The message shown by `localizedDescription`.
    ///
    /// - Warning: These messages are hard-coded Japanese and are not localized, so they
    ///   reach the customer in Japanese whatever the device language. Map the case to your
    ///   own copy rather than displaying this directly.
    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "サブスクリプションが初期化されていません"
        case .invalidConfiguration(let message):
            return "設定エラー: \(message)"
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        case .purchaseCancelled:
            return "購入がキャンセルされました"
        case .purchaseFailed(let error):
            return "購入に失敗しました: \(error.localizedDescription)"
        case .restoreFailed(let error):
            return "復元に失敗しました: \(error.localizedDescription)"
        case .offeringsNotAvailable:
            return "商品情報を取得できませんでした"
        case .packageNotFound(let id):
            return "商品が見つかりません: \(id)"
        case .userSyncFailed(let error):
            return "ユーザー同期に失敗しました: \(error.localizedDescription)"
        case .unknown(let error):
            return "エラーが発生しました: \(error.localizedDescription)"
        }
    }
}
