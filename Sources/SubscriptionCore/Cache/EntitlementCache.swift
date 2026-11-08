import Foundation

/// Where the last entitlement the store confirmed is kept between launches.
///
/// Without one, a cold launch out of signal answers `.inactive` for every paying customer,
/// because the only thing that could have said otherwise is a network call that failed. The
/// place is injected rather than chosen by this package: an app group's defaults, a file in a
/// container the app already backs up, or the keychain are all reasonable and the package
/// cannot know which of them this app has.
///
/// ## Best effort, by contract
///
/// None of these calls can fail in a way a caller could act on, so none of them report
/// failure: a read that cannot produce a record answers `nil`, and a write that cannot land is
/// dropped. The store remains the authority — an entitlement is never held *only* here — so a
/// cache that never works degrades to the behaviour of not having one, not to a wrong answer.
///
/// ## Concurrency
///
/// Calls arrive from ``SubscriptionUseCaseImpl``'s actor, so they are already serialised
/// against each other. A conformance still has to be safe against the rest of the app touching
/// the same place.
public protocol EntitlementCache: Sendable {
    /// Returns the stored record, or `nil` when there is none to read.
    func read() -> CachedEntitlement?

    /// Replaces the stored record.
    func write(_ entitlement: CachedEntitlement)

    /// Removes the stored record.
    ///
    /// Called when the identity changes, which is the one moment a stale record would grant one
    /// customer's entitlement to another.
    func clear()
}
