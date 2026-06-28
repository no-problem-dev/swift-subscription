# Getting Started

`Subscription` ライブラリを Swift Package Manager で導入し、サブスクリプション機能を実装する手順。

## インストール

`Package.swift` の `dependencies` に追加する。

```swift
dependencies: [
    .package(
        url: "https://github.com/no-problem-dev/swift-subscription.git",
        from: "1.0.4"
    )
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "Subscription", package: "swift-subscription")
        ]
    )
]
```

## 基本的な使い方

### 1. 設定とインスタンス生成

RevenueCat ダッシュボードで取得した API キーと、エンタイトルメント ID を使って
`SubscriptionConfiguration` を作成し、`SubscriptionUseCaseImpl` を初期化する。

```swift
import Subscription

let config = SubscriptionConfiguration(
    apiKey: "appl_xxxxxxxxxxxxxxxxxxxxxxxxxx",
    entitlementId: "premium"
)
let subscriptionUseCase: SubscriptionUseCase = SubscriptionUseCaseImpl(configuration: config)
```

SwiftUI アプリでは App エントリーポイントで DI する。

```swift
@main
struct MyApp: App {
    private let subscriptionUseCase: SubscriptionUseCase = SubscriptionUseCaseImpl(
        configuration: SubscriptionConfiguration(apiKey: "appl_xxxxxx")
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
                .subscriptionUseCase(subscriptionUseCase)
        }
    }
}
```

View 側では `@Environment` で受け取る。

```swift
struct PaywallView: View {
    @Environment(\.subscriptionUseCase) private var subscriptionUseCase
}
```

### 2. 商品取得

利用可能なプランを `loadOfferings()` で取得する。

```swift
guard let subscriptionUseCase else { return }
let offering = try await subscriptionUseCase.loadOfferings()
if let packages = offering?.packages {
    for package in packages {
        print("\(package.title): \(package.price)")
        // 例: "年間プラン: ¥6,000"
    }
}
```

### 3. 購入

`purchase(packageId:)` にプランの `id` を渡して購入する。
ユーザーがキャンセルした場合は `SubscriptionError.purchaseCancelled` がスローされる。

```swift
do {
    let status = try await subscriptionUseCase.purchase(packageId: "annual")
    if status.isActive {
        // プレミアム機能を有効化
    }
} catch SubscriptionError.purchaseCancelled {
    // ユーザーがキャンセル — エラー表示不要
} catch {
    // ネットワークエラーなどを表示
    print(error.localizedDescription)
}
```

### 4. サブスクリプション状態の監視

`observeSubscriptionStatus()` は `AsyncStream<SubscriptionStatus>` を返す。
RevenueCat からのプッシュ通知（購入完了・期限切れ）に応じてリアルタイムで更新される。

```swift
Task {
    guard let subscriptionUseCase else { return }
    for await status in subscriptionUseCase.observeSubscriptionStatus() {
        await MainActor.run {
            isPremium = status.isActive
        }
    }
}
```

キャッシュ済みの状態を取得したい場合は `getSubscriptionStatus()` を使う。

```swift
guard let subscriptionUseCase else { return }
let status = await subscriptionUseCase.getSubscriptionStatus()
```

### 5. 購入の復元

別のデバイスや再インストール後に購入を復元する。

```swift
let status = try await subscriptionUseCase.restorePurchases()
```

### 6. ユーザー同期

認証済みユーザー ID を RevenueCat と紐付ける。ログイン後に呼び出す。

```swift
try await subscriptionUseCase.syncUser(userId: user.id)
// ログアウト時
try await subscriptionUseCase.clearUser()
```
