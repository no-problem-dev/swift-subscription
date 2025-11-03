import Foundation

/// サブスクリプションリポジトリのプロトコル
protocol SubscriptionRepository: Sendable {
    /// サブスクリプション状態をチェック
    func checkSubscriptionStatus() async throws -> SubscriptionStatus

    /// オファリング（商品情報）を読み込み
    func loadOfferings() async throws -> SubscriptionOffering?

    /// 購入処理
    func purchase(packageId: String) async throws -> SubscriptionStatus

    /// 購入の復元
    func restorePurchases() async throws -> SubscriptionStatus

    /// ユーザーIDでログイン
    func syncUser(userId: String) async throws

    /// ログアウト
    func clearUser() async throws

    /// サブスクリプション状態の変更を監視
    func observeSubscriptionChanges() -> AsyncStream<SubscriptionStatus>
}
