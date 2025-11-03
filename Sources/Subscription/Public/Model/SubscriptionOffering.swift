import Foundation

/// サブスクリプションプランの課金期間
public enum PackageDuration: String, Sendable {
    /// 月額プラン
    case monthly = "月額"
    /// 年額プラン
    case annual = "年額"
    /// 買い切りプラン
    case lifetime = "買い切り"
    /// 不明なプラン
    case unknown = ""
}

/// 購入可能なサブスクリプションプランの情報
///
/// App Store / Google Play Storeで設定されたプランの詳細情報を保持します。
public struct SubscriptionPackage: Sendable, Identifiable {
    /// プランを一意に識別するID
    public let id: String

    /// プランの表示名（例: "年間プラン"）
    public let title: String

    /// プランの説明文
    public let description: String

    /// 価格の表示文字列（例: "¥6,000"）
    public let price: String

    /// 月額換算の価格表示文字列（年額プランの場合のみ、例: "¥500/月"）
    public let pricePerMonth: String?

    /// プランの課金期間
    public let duration: PackageDuration

    public init(
        id: String,
        title: String,
        description: String,
        price: String,
        pricePerMonth: String?,
        duration: PackageDuration
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.price = price
        self.pricePerMonth = pricePerMonth
        self.duration = duration
    }
}

/// 購入可能なサブスクリプションプランのグループ
///
/// RevenueCatで設定したオファリング（プランのグループ）を表します。
/// 通常、月額・年額・買い切りなど複数のプランが含まれます。
///
/// ## 使用例
/// ```swift
/// let offerings = try await subscriptionUseCase.loadOfferings()
/// if let packages = offerings?.packages {
///     for package in packages {
///         print("\(package.title): \(package.price)")
///     }
/// }
/// ```
public struct SubscriptionOffering: Sendable, Identifiable {
    /// オファリングを一意に識別するID
    public let id: String

    /// 購入可能なプランの配列
    public let packages: [SubscriptionPackage]

    public init(id: String, packages: [SubscriptionPackage]) {
        self.id = id
        self.packages = packages
    }
}
