// The values and the port live in `SubscriptionCore`, a module with no RevenueCat, so an app's
// presentation layer can name them without building the SDK. Re-exported here so
// `import Subscription` still sees them, and `PackageDuration`, which `SubscriptionCore`
// re-exports in turn.
@_exported import SubscriptionCore
