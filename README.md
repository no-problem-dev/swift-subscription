# Subscription

RevenueCatを使用したサブスクリプション管理のためのSwiftパッケージ

![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017.0%2B%20%7C%20macOS%2014.0%2B-blue.svg)
![SPM](https://img.shields.io/badge/SPM-compatible-green.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

📚 **[完全なドキュメント](https://no-problem-dev.github.io/swift-subscription/documentation/subscription/)**

## 概要

SubscriptionパッケージはRevenueCatと統合し、アプリ内課金（サブスクリプション）の実装を簡潔に行うための高レベルAPIを提供します。

### 主な機能

- ✅ サブスクリプション状態の確認と監視
- ✅ 利用可能なプランの取得
- ✅ プランの購入と復元
- ✅ ユーザー認証との連携
- ✅ SwiftUI対応（async/await、AsyncStream）
- ✅ Actor-basedのスレッドセーフな設計

## 必要要件

- **iOS** 17.0+ / **macOS** 14.0+
- **Swift** 6.0+
- **RevenueCat SDK** 5.14.0+

## 前提条件

### RevenueCatプロジェクトのセットアップ

[RevenueCat Dashboard](https://app.revenuecat.com/)で以下の設定を完了してください：

1. **プロジェクトの作成**
   - 新規プロジェクトを作成
   - APIキーを取得

2. **プロダクトの設定**
   - App Store Connect / Google Play Consoleでサブスクリプションプロダクトを作成
   - RevenueCat Dashboardでプロダクトをインポート
   - エンタイトルメントを設定（例: "premium"）

3. **オファリングの作成**
   - 月額・年額などのプランをオファリングとしてグループ化
   - デフォルトオファリングを設定

## インストール

### Swift Package Manager

`Package.swift`に以下を追加：

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-subscription.git", from: "1.0.0")
]
```

または、Xcode で `File > Add Package Dependencies...` から `https://github.com/no-problem-dev/swift-subscription` を追加できます。

## クイックスタート

### 1. 初期化

```swift
import Subscription

@main
struct YourApp: App {
    init() {
        let config = SubscriptionConfiguration(
            apiKey: "your_revenuecat_api_key",
            entitlementId: "premium"
        )
        let subscriptionUseCase = SubscriptionUseCaseImpl(configuration: config)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 2. サブスクリプション状態の確認

```swift
// キャッシュされた状態を即座に取得
let status = await subscriptionUseCase.getSubscriptionStatus()

// サーバーから最新の状態を取得
let latestStatus = try await subscriptionUseCase.checkSubscriptionStatus()

if latestStatus.isActive {
    print("加入中: \(latestStatus.activePackageId ?? "不明")")
}
```

### 3. プランの取得と購入

```swift
// 利用可能なプランを取得
let offerings = try await subscriptionUseCase.loadOfferings()

if let packages = offerings?.packages {
    for package in packages {
        print("\(package.title): \(package.price)")
    }

    // プランを購入
    if let package = packages.first {
        let status = try await subscriptionUseCase.purchase(packageId: package.id)
    }
}
```

### 4. リアルタイム監視

```swift
// サブスクリプション状態の変化を監視
Task {
    for await status in subscriptionUseCase.observeSubscriptionStatus() {
        if status.isActive {
            // プレミアム機能を有効化
        }
    }
}
```

## 使用例

### SwiftUIでの統合

```swift
import SwiftUI
import Subscription

struct ContentView: View {
    @Environment(\.subscriptionUseCase) private var subscriptionUseCase
    @State private var status: SubscriptionStatus = .inactive

    var body: some View {
        VStack {
            if status.isActive {
                Text("プレミアム会員")
            } else {
                Button("プレミアムプランに登録") {
                    Task { await showPaywall() }
                }
            }
        }
        .task {
            for await newStatus in subscriptionUseCase.observeSubscriptionStatus() {
                status = newStatus
            }
        }
    }

    private func showPaywall() async {
        // ペイウォール表示の実装
    }
}
```

### ユーザー認証との連携

```swift
// ユーザーログイン時
func userDidLogin(userId: String) async throws {
    try await subscriptionUseCase.syncUser(userId: userId)
}

// ユーザーログアウト時
func userDidLogout() async throws {
    try await subscriptionUseCase.clearUser()
}
```

### エラーハンドリング

```swift
do {
    let status = try await subscriptionUseCase.purchase(packageId: packageId)
} catch let error as SubscriptionError {
    switch error {
    case .purchaseCancelled:
        // ユーザーがキャンセル - エラー表示不要
        break
    case .networkError:
        // ネットワークエラーの場合は再試行を促す
        showRetryAlert()
    default:
        showAlert(message: error.localizedDescription)
    }
}
```

## 依存関係

- [RevenueCat SDK](https://github.com/RevenueCat/purchases-ios) (5.14.0+)

## ライセンス

MIT License

## サポート

問題が発生した場合や機能リクエストがある場合は、[GitHubのIssue](https://github.com/no-problem-dev/swift-subscription/issues)を作成してください。
