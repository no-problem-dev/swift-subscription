import Foundation

/// An ``EntitlementCache`` that keeps the record in one JSON file.
///
/// The URL is required, because the point of injecting the cache is choosing where it lives.
/// Application Support is the usual answer for an app that has no app group:
///
/// ```swift
/// let directory = URL.applicationSupportDirectory.appending(path: "Subscription")
/// let cache = FileEntitlementCache(url: directory.appending(path: "entitlement.json"))
/// ```
///
/// Intermediate directories are created on the first write. The file goes to the container the
/// app owns, so deleting the app takes it — a reinstall is a first launch again and asks the
/// store. Use a keychain-backed conformance instead when the entitlement has to outlive the
/// app's container.
public struct FileEntitlementCache: EntitlementCache {
    private let url: URL

    /// Creates a cache backed by a file.
    ///
    /// - Parameter url: The file to keep the record in. Its directory is created if needed.
    public init(url: URL) {
        self.url = url
    }

    public func read() -> CachedEntitlement? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CachedEntitlement.self, from: data)
    }

    public func write(_ entitlement: CachedEntitlement) {
        guard let data = try? JSONEncoder().encode(entitlement) else { return }

        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    public func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
