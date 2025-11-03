import Foundation

/// サブスクリプション機能の初期化に必要な設定情報
///
/// ## 使用例
/// ```swift
/// let config = SubscriptionConfiguration(
///     apiKey: "your_revenuecat_api_key",
///     entitlementId: "premium"
/// )
/// let subscriptionUseCase = SubscriptionUseCaseImpl(configuration: config)
/// ```
public struct SubscriptionConfiguration: Sendable {
    /// RevenueCat APIキー
    ///
    /// RevenueCatダッシュボードから取得したAPIキーを指定してください。
    public let apiKey: String

    /// プレミアム機能を識別するエンタイトルメントID
    ///
    /// RevenueCatで設定したエンタイトルメント名を指定します。
    /// デフォルト値は`"premium"`です。
    public let entitlementId: String

    /// ユーザー同期時に追加のカスタム属性を設定するためのコールバック（オプション）
    ///
    /// ユーザーIDとともに追加の属性をRevenueCatに送信したい場合に使用します。
    public let customAttributesSetter: (@Sendable (String) async -> Void)?

    public init(
        apiKey: String,
        entitlementId: String = "premium",
        customAttributesSetter: (@Sendable (String) async -> Void)? = nil
    ) {
        self.apiKey = apiKey
        self.entitlementId = entitlementId
        self.customAttributesSetter = customAttributesSetter
    }
}
