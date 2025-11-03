import Foundation

/// サブスクリプション状態（内部専用）
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
