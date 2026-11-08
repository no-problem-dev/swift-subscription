/// How long one purchase lasts.
///
/// The raw values are stable identifiers meant for logging and analytics, not labels.
/// Switch over the case to build a label your app owns and localizes — a paywall is the
/// last place a package should be choosing wording on your behalf.
public enum PackageDuration: String, Sendable, Hashable {
    case monthly
    case annual
    case lifetime

    /// A period this package does not model, such as weekly or a custom store duration.
    ///
    /// Reachable for products that are perfectly valid in the store, so treat it as a
    /// product to present rather than an error.
    case unknown
}
