import Foundation

/// The cached view of the customer's entitlement, shared by every caller of the use case.
///
/// An actor because the store's change feed and app code both write here. The values are a
/// cache of the last answer received, never a source of truth: nothing in this type expires
/// an entitlement, so a status stays `isActive` until a refresh replaces it.
actor SubscriptionState {
    private(set) var status: SubscriptionStatus = .inactive
    private(set) var offerings: SubscriptionOffering?
    private(set) var userId: String?

    init() {}

    // MARK: - State Mutations

    func setStatus(_ status: SubscriptionStatus) {
        self.status = status
    }

    func setOfferings(_ offerings: SubscriptionOffering?) {
        self.offerings = offerings
    }

    func setUserId(_ userId: String?) {
        self.userId = userId
    }
}
