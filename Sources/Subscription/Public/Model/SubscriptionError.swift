import Foundation

/// サブスクリプション処理で発生する可能性のあるエラー
///
/// ## エラーハンドリング例
/// ```swift
/// do {
///     let status = try await subscriptionUseCase.purchase(packageId: "annual")
/// } catch let error as SubscriptionError {
///     switch error {
///     case .purchaseCancelled:
///         // ユーザーがキャンセル - エラー表示不要
///         break
///     default:
///         // エラーメッセージを表示
///         showAlert(message: error.localizedDescription)
///     }
/// } catch {
///     showAlert(message: "予期しないエラーが発生しました")
/// }
/// ```
public enum SubscriptionError: Error, LocalizedError {
    /// サブスクリプションシステムが初期化されていない
    case notConfigured
    /// 設定情報が不正
    case invalidConfiguration(String)
    /// ネットワーク通信エラー
    case networkError(Error)
    /// ユーザーが購入をキャンセル
    case purchaseCancelled
    /// 購入処理に失敗
    case purchaseFailed(Error)
    /// 購入の復元に失敗
    case restoreFailed(Error)
    /// プラン情報の取得に失敗
    case offeringsNotAvailable
    /// 指定されたプランが見つからない
    case packageNotFound(String)
    /// ユーザーIDの同期に失敗
    case userSyncFailed(Error)
    /// その他のエラー
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "サブスクリプションが初期化されていません"
        case .invalidConfiguration(let message):
            return "設定エラー: \(message)"
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        case .purchaseCancelled:
            return "購入がキャンセルされました"
        case .purchaseFailed(let error):
            return "購入に失敗しました: \(error.localizedDescription)"
        case .restoreFailed(let error):
            return "復元に失敗しました: \(error.localizedDescription)"
        case .offeringsNotAvailable:
            return "商品情報を取得できませんでした"
        case .packageNotFound(let id):
            return "商品が見つかりません: \(id)"
        case .userSyncFailed(let error):
            return "ユーザー同期に失敗しました: \(error.localizedDescription)"
        case .unknown(let error):
            return "エラーが発生しました: \(error.localizedDescription)"
        }
    }
}
