import Foundation

/// An ``EntitlementCache`` that keeps the record in a `UserDefaults` suite.
///
/// The suite is required. `UserDefaults.standard` is deliberately not a default: an extension
/// or a widget that has to know whether the customer is entitled reads a different `standard`
/// from the app's, and tests running in parallel against `standard` write over each other's
/// records.
///
/// ```swift
/// let defaults = UserDefaults(suiteName: "group.com.example.app")!
/// let cache = UserDefaultsEntitlementCache(defaults: defaults)
/// ```
public struct UserDefaultsEntitlementCache: EntitlementCache, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    /// Creates a cache backed by a defaults suite.
    ///
    /// - Parameters:
    ///   - defaults: The suite to store in. An app group's suite is what makes the record
    ///     readable from an extension.
    ///   - key: The key to store under. Change it only to avoid a collision.
    public init(defaults: UserDefaults, key: String = "subscription.cachedEntitlement") {
        self.defaults = defaults
        self.key = key
    }

    public func read() -> CachedEntitlement? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CachedEntitlement.self, from: data)
    }

    public func write(_ entitlement: CachedEntitlement) {
        guard let data = try? JSONEncoder().encode(entitlement) else { return }
        defaults.set(data, forKey: key)
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
