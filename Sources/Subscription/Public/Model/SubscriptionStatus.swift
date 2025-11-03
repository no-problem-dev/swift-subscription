import Foundation

/// ユーザーのサブスクリプション状態を表します。
///
/// この構造体は、ユーザーが現在どのサブスクリプションプランに加入しているかの情報を保持します。
///
/// ## 使用例
/// ```swift
/// let status = try await subscriptionUseCase.checkSubscriptionStatus()
///
/// if status.isActive {
///     print("加入中のプラン: \(status.activePackageId ?? "不明")")
///     if let expiration = status.expirationDate {
///         print("有効期限: \(expiration)")
///     }
/// } else {
///     print("未加入")
/// }
/// ```
public struct SubscriptionStatus: Sendable, Equatable {
    /// 有効なサブスクリプションに加入しているかどうか
    public let isActive: Bool

    /// 有効なエンタイトルメントID（加入していない場合は `nil`）
    public let activeEntitlementId: String?

    /// 加入中のプランのパッケージID（月額/年額/買い切りなどを識別、加入していない場合は `nil`）
    public let activePackageId: String?

    /// サブスクリプションの有効期限（買い切りプランや加入していない場合は `nil`）
    public let expirationDate: Date?

    public init(
        isActive: Bool,
        activeEntitlementId: String? = nil,
        activePackageId: String? = nil,
        expirationDate: Date? = nil
    ) {
        self.isActive = isActive
        self.activeEntitlementId = activeEntitlementId
        self.activePackageId = activePackageId
        self.expirationDate = expirationDate
    }

    /// サブスクリプションが非アクティブ状態を表す定数
    public static let inactive = SubscriptionStatus(
        isActive: false,
        activeEntitlementId: nil,
        activePackageId: nil,
        expirationDate: nil
    )
}
