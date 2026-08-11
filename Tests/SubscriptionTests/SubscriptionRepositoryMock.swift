import Foundation
@testable import Subscription

/// A repository that answers from values the test sets, so the use case can be exercised
/// without the RevenueCat SDK or a StoreKit session.
actor SubscriptionRepositoryMock: SubscriptionRepository {
    private var statusToReturn: SubscriptionStatus = .inactive
    private var offeringToReturn: SubscriptionOffering?
    private var errorToThrow: Error?
    private(set) var syncedUserIds: [String] = []
    private(set) var clearUserCallCount = 0

    /// Pushes a status into the stream, standing in for a change the store would push.
    nonisolated let changesContinuation: AsyncStream<SubscriptionStatus>.Continuation
    private nonisolated let changes: AsyncStream<SubscriptionStatus>

    init() {
        (changes, changesContinuation) = AsyncStream.makeStream()
    }

    // MARK: - Test Setup

    func setStatus(_ status: SubscriptionStatus) {
        statusToReturn = status
    }

    func setOffering(_ offering: SubscriptionOffering?) {
        offeringToReturn = offering
    }

    func setError(_ error: Error?) {
        errorToThrow = error
    }

    // MARK: - SubscriptionRepository

    func checkSubscriptionStatus() async throws -> SubscriptionStatus {
        try throwIfNeeded()
        return statusToReturn
    }

    func loadOfferings() async throws -> SubscriptionOffering? {
        try throwIfNeeded()
        return offeringToReturn
    }

    func purchase(packageId: String) async throws -> SubscriptionStatus {
        try throwIfNeeded()
        return statusToReturn
    }

    func restorePurchases() async throws -> SubscriptionStatus {
        try throwIfNeeded()
        return statusToReturn
    }

    func syncUser(userId: String) async throws {
        try throwIfNeeded()
        syncedUserIds.append(userId)
    }

    func clearUser() async throws {
        try throwIfNeeded()
        clearUserCallCount += 1
    }

    nonisolated func observeSubscriptionChanges() -> AsyncStream<SubscriptionStatus> {
        changes
    }

    // MARK: - Private

    private func throwIfNeeded() throws {
        if let errorToThrow {
            throw errorToThrow
        }
    }
}
