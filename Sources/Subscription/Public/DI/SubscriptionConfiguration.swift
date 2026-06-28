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
    /// RevenueCat API キー
    ///
    /// RevenueCat ダッシュボードから取得した API キーを設定する。
    public let apiKey: String

    /// プレミアム機能を識別するエンタイトルメント ID
    ///
    /// RevenueCat で設定したエンタイトルメント名。
    /// デフォルト値は `"premium"`。
    public let entitlementId: String

    /// ユーザー同期時に追加のカスタム属性を設定するためのコールバック（オプション）
    ///
    /// ユーザー ID とともに追加の属性を RevenueCat に送信したい場合に設定する。
    public let customAttributesSetter: (@Sendable (String) async -> Void)?

    /// `SubscriptionConfiguration` を生成する。
    ///
    /// - Parameters:
    ///   - apiKey: RevenueCat ダッシュボードから取得した API キー。
    ///   - entitlementId: プレミアム機能に対応するエンタイトルメント ID。省略時は `"premium"`。
    ///   - customAttributesSetter: ユーザー同期時に追加属性を RevenueCat へ送信するコールバック。不要な場合は `nil`。
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
