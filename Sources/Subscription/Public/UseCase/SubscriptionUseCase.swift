import Foundation

/// サブスクリプション機能を提供するユースケース
///
/// このプロトコルは、アプリ内課金（サブスクリプション）の主要な操作を定義します。
/// RevenueCatを使用した実装が提供されています。
///
/// ## 主な機能
/// - サブスクリプション状態の確認と監視
/// - 利用可能なプランの取得
/// - プランの購入と復元
/// - ユーザー認証との連携
///
/// ## 使用例
/// ```swift
/// // 状態の確認
/// let status = try await subscriptionUseCase.checkSubscriptionStatus()
/// if status.isActive {
///     // プレミアム機能を有効化
/// }
///
/// // プランの購入
/// let offerings = try await subscriptionUseCase.loadOfferings()
/// if let package = offerings?.packages.first {
///     let status = try await subscriptionUseCase.purchase(packageId: package.id)
/// }
///
/// // リアルタイム監視
/// for await status in subscriptionUseCase.observeSubscriptionStatus() {
///     // 状態変化に応じてUIを更新
/// }
/// ```
public protocol SubscriptionUseCase: Sendable {
    /// サブスクリプション状態の変化をリアルタイムで監視します
    ///
    /// - Returns: サブスクリプション状態の変化を通知する`AsyncStream`
    /// - Note: このストリームは状態が変化するたびに新しい値を返します
    func observeSubscriptionStatus() -> AsyncStream<SubscriptionStatus>

    /// キャッシュされた現在のサブスクリプション状態を取得します
    ///
    /// - Returns: 現在のサブスクリプション状態
    /// - Note: サーバーへの問い合わせは行わず、キャッシュされた値を即座に返します
    func getSubscriptionStatus() async -> SubscriptionStatus

    /// サーバーに問い合わせて最新のサブスクリプション状態を確認します
    ///
    /// - Returns: 最新のサブスクリプション状態
    /// - Throws: ネットワークエラーやサーバーエラーが発生した場合
    func checkSubscriptionStatus() async throws -> SubscriptionStatus

    /// 購入可能なサブスクリプションプランを取得します
    ///
    /// - Returns: 利用可能なプラン情報（利用可能なプランがない場合は`nil`）
    /// - Throws: プラン情報の取得に失敗した場合
    func loadOfferings() async throws -> SubscriptionOffering?

    /// 指定されたプランを購入します
    ///
    /// - Parameter packageId: 購入するプランのID
    /// - Returns: 購入後のサブスクリプション状態
    /// - Throws: 購入処理に失敗した場合、またはユーザーがキャンセルした場合
    func purchase(packageId: String) async throws -> SubscriptionStatus

    /// 過去に購入したプランを復元します
    ///
    /// - Returns: 復元後のサブスクリプション状態
    /// - Throws: 復元処理に失敗した場合
    /// - Note: デバイス間でサブスクリプションを同期する際に使用します
    func restorePurchases() async throws -> SubscriptionStatus

    /// ユーザーIDをサブスクリプションシステムと同期します
    ///
    /// - Parameter userId: 同期するユーザーID
    /// - Throws: 同期処理に失敗した場合
    /// - Note: ユーザー認証後に呼び出してください
    func syncUser(userId: String) async throws

    /// ユーザーをログアウトしてサブスクリプション情報をクリアします
    ///
    /// - Throws: ログアウト処理に失敗した場合
    func clearUser() async throws
}
