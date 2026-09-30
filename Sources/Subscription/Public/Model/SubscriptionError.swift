import Foundation

/// A failure raised by a subscription operation.
///
/// ``purchaseCancelled`` and ``purchasePending`` are ordinary outcomes; the rest are genuine
/// failures. Match those two before any generic error handling, because presenting either as an
/// error tells a customer that something broke when they simply changed their mind, or are
/// waiting for a parent to approve.
///
/// ## Example
/// ```swift
/// do {
///     let status = try await subscriptionUseCase.purchase(packageId: "annual")
/// } catch SubscriptionError.purchaseCancelled {
///     // Expected. Dismiss quietly.
/// } catch SubscriptionError.purchasePending {
///     // Ask to Buy. Say it is waiting for approval; the entitlement arrives later.
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

    /// The store could not be reached while reading the entitlement or the products.
    ///
    /// Worth a retry. Access already granted should be left alone, since being offline is
    /// not evidence that a subscription ended.
    case networkError(Error)

    /// The customer dismissed the purchase sheet. Expected, and not an error to display.
    case purchaseCancelled

    /// The purchase is waiting for someone else's approval — Ask to Buy, or a bank's strong
    /// customer authentication. Expected, and not an error to display.
    ///
    /// Nothing is charged yet and the customer is not entitled yet. If the purchase is approved
    /// later, the entitlement arrives through
    /// ``SubscriptionUseCase/observeSubscriptionStatus()`` without the app asking again.
    case purchasePending

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

    /// No package in the offering has the requested identifier, or there is no such offering.
    ///
    /// Usually an App Store product identifier passed where the offering's package
    /// identifier was expected, or a paywall built against an offering that is no longer
    /// current. The associated value is the package identifier.
    case packageNotFound(String)

    /// Attaching or detaching the billing identity failed, leaving purchases attributed to
    /// the previous identity.
    case userSyncFailed(Error)

    /// The message shown by `localizedDescription`.
    ///
    /// - Warning: These messages are hard-coded English and are not localized, so they
    ///   reach the customer in English whatever the device language. Map the case to your
    ///   own copy rather than displaying this directly.
    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "The subscription service is not configured."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .purchaseCancelled:
            return "The purchase was cancelled."
        case .purchasePending:
            return "The purchase is waiting for approval."
        case .purchaseFailed(let error):
            return "The purchase failed: \(error.localizedDescription)"
        case .restoreFailed(let error):
            return "Restoring purchases failed: \(error.localizedDescription)"
        case .packageNotFound(let id):
            return "No package was found with the identifier \(id)."
        case .userSyncFailed(let error):
            return "Syncing the user failed: \(error.localizedDescription)"
        }
    }
}
