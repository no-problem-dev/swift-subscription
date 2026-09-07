import Foundation

/// An ``EntitlementCache`` that forgets everything when the process ends.
///
/// For tests and previews. In an app it is the same as having no cache at all — every cold
/// launch starts unverified — so an app that ships this has not fixed anything.
public final class InMemoryEntitlementCache: EntitlementCache, @unchecked Sendable {
    private let lock = NSLock()
    private var entitlement: CachedEntitlement?

    /// Creates a cache, optionally starting from a record.
    ///
    /// - Parameter entitlement: The record a launch should find already there. This is how a
    ///   test stands in for a previous launch having confirmed something.
    public init(entitlement: CachedEntitlement? = nil) {
        self.entitlement = entitlement
    }

    public func read() -> CachedEntitlement? {
        lock.withLock { entitlement }
    }

    public func write(_ entitlement: CachedEntitlement) {
        lock.withLock { self.entitlement = entitlement }
    }

    public func clear() {
        lock.withLock { entitlement = nil }
    }
}
