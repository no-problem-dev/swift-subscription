# ``Subscription``

RevenueCat を使ったアプリ内課金・サブスクリプションを Swift らしい API で扱う軽量ライブラリ。

## Overview

`Subscription` ライブラリは、iOS / macOS アプリにサブスクリプション機能を追加するための
シンプルなインターフェースを提供します。RevenueCat SDK をラップし、
購入フロー・状態監視・ユーザー同期を `async/await` ベースの API で統一します。

```swift
// 1. 設定
let config = SubscriptionConfiguration(
    apiKey: "your_revenuecat_api_key",
    entitlementId: "premium"
)
let useCase = SubscriptionUseCaseImpl(configuration: config)

// 2. 商品取得
let offering = try await useCase.loadOfferings()

// 3. 購入
if let package = offering?.packages.first {
    let status = try await useCase.purchase(packageId: package.id)
    print(status.isActive ? "購入完了" : "未加入")
}

// 4. 状態監視
for await status in useCase.observeSubscriptionStatus() {
    updateUI(isActive: status.isActive)
}
```

SwiftUI アプリでは `View.subscriptionUseCase(_:)` モディファイアで DI できます。

```swift
ContentView()
    .subscriptionUseCase(useCase)
```

## Topics

### Essentials

- <doc:GettingStarted>

### ユースケース

- ``SubscriptionUseCase``
- ``SubscriptionUseCaseImpl``

### 設定・DI

- ``SubscriptionConfiguration``
- ``SubscriptionUseCaseModifier``

### モデル

- ``SubscriptionStatus``
- ``SubscriptionOffering``
- ``SubscriptionPackage``
- ``PackageDuration``

### エラー

- ``SubscriptionError``
