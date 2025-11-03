# Subscription

RevenueCatを使用したサブスクリプション管理のためのSwiftパッケージ

## 概要

SubscriptionパッケージはRevenueCatと統合し、アプリ内課金（サブスクリプション）の実装を簡潔に行うための高レベルAPIを提供します。

### 主な機能

- ✅ サブスクリプション状態の確認と監視
- ✅ 利用可能なプランの取得
- ✅ プランの購入と復元
- ✅ ユーザー認証との連携
- ✅ SwiftUI対応のモダンなAPI（async/await、AsyncStream）
- ✅ 完全なSendableサポート
- ✅ Actor-basedのスレッドセーフな設計

## 要件

- iOS 17.0+
- Swift 5.9+
- RevenueCat SDK 5.46.0+

## インストール

### Swift Package Manager

`Package.swift`に以下を追加：

```swift
dependencies: [
    .package(url: "https://github.com/your-repo/Subscription.git", from: "1.0.0")
]
```

または、Xcode で `File > Add Package Dependencies...` から追加できます。

## セットアップ

### 1. RevenueCat APIキーの取得

[RevenueCat Dashboard](https://app.revenuecat.com/)でプロジェクトを作成し、APIキーを取得してください。

### 2. 初期化

```swift
import Subscription

// 設定の作成
let config = SubscriptionConfiguration(
    apiKey: "your_revenuecat_api_key",
    entitlementId: "premium"
)

// ユースケースの初期化
let subscriptionUseCase = SubscriptionUseCaseImpl(configuration: config)
```

## 使用方法

### サブスクリプション状態の確認

```swift
// 最新の状態を取得
let status = try await subscriptionUseCase.checkSubscriptionStatus()

if status.isActive {
    print("加入中: \(status.activePackageId ?? "不明")")
} else {
    print("未加入")
}
```

### プランの取得と購入

```swift
// 利用可能なプランを取得
let offerings = try await subscriptionUseCase.loadOfferings()

if let packages = offerings?.packages {
    for package in packages {
        print("\(package.title): \(package.price)")

        if package.duration == .annual, let monthlyPrice = package.pricePerMonth {
            print("月額換算: \(monthlyPrice)")
        }
    }

    // プランを購入
    if let annualPackage = packages.first(where: { $0.duration == .annual }) {
        do {
            let status = try await subscriptionUseCase.purchase(packageId: annualPackage.id)
            if status.isActive {
                print("購入成功！")
            }
        } catch let error as SubscriptionError {
            switch error {
            case .purchaseCancelled:
                // ユーザーがキャンセル - エラー表示不要
                break
            default:
                print("エラー: \(error.localizedDescription)")
            }
        }
    }
}
```

### 購入の復元

```swift
do {
    let status = try await subscriptionUseCase.restorePurchases()
    if status.isActive {
        print("復元成功: \(status.activePackageId ?? "不明")")
    } else {
        print("復元可能なサブスクリプションが見つかりませんでした")
    }
} catch {
    print("復元エラー: \(error.localizedDescription)")
}
```

### リアルタイム監視

```swift
// サブスクリプション状態の変化を監視
Task {
    for await status in subscriptionUseCase.observeSubscriptionStatus() {
        if status.isActive {
            // プレミアム機能を有効化
            enablePremiumFeatures()
        } else {
            // プレミアム機能を無効化
            disablePremiumFeatures()
        }
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

### SwiftUIでの使用例

```swift
import SwiftUI
import Subscription

struct ContentView: View {
    @State private var subscriptionStatus: SubscriptionStatus = .inactive

    let subscriptionUseCase: SubscriptionUseCase

    var body: some View {
        VStack {
            if subscriptionStatus.isActive {
                Text("プレミアム会員")
                    .font(.headline)
            } else {
                Button("プレミアムプランを見る") {
                    Task {
                        await showPaywall()
                    }
                }
            }
        }
        .task {
            // 初回の状態取得
            subscriptionStatus = await subscriptionUseCase.getSubscriptionStatus()

            // リアルタイム監視
            for await status in subscriptionUseCase.observeSubscriptionStatus() {
                subscriptionStatus = status
            }
        }
    }

    private func showPaywall() async {
        // ペイウォール表示の実装
    }
}
```

## アーキテクチャ

### パッケージ構造

```
Subscription/
├── Public/          # 公開API
│   ├── Model/       # データモデル
│   ├── UseCase/     # ユースケース（プロトコルと実装）
│   └── DI/          # 設定
└── Internal/        # 内部実装（非公開）
    ├── Domain/      # ドメインロジック
    ├── Repository/  # RevenueCat統合
    └── Model/       # 内部状態管理
```

### 主要な型

#### `SubscriptionUseCase`
サブスクリプション機能の主要なインターフェース。すべての操作はこのプロトコルを通じて行います。

#### `SubscriptionStatus`
ユーザーのサブスクリプション状態を表現：
- `isActive`: 加入しているか
- `activePackageId`: 加入中のプランID
- `activeEntitlementId`: エンタイトルメントID
- `expirationDate`: 有効期限

#### `SubscriptionOffering`
購入可能なプランのグループ。通常、月額・年額・買い切りなどが含まれます。

#### `SubscriptionError`
サブスクリプション処理で発生する可能性のあるエラー。`LocalizedError`に準拠しているため、ユーザーフレンドリーなエラーメッセージを取得できます。

## ベストプラクティス

### エラーハンドリング

```swift
do {
    let status = try await subscriptionUseCase.purchase(packageId: packageId)
    // 成功時の処理
} catch let error as SubscriptionError {
    switch error {
    case .purchaseCancelled:
        // ユーザーがキャンセルした場合は何もしない
        break
    case .networkError:
        // ネットワークエラーの場合は再試行を促す
        showRetryAlert()
    default:
        // その他のエラーはメッセージを表示
        showAlert(message: error.localizedDescription)
    }
} catch {
    // 予期しないエラー
    showAlert(message: "予期しないエラーが発生しました")
}
```

### 状態管理

```swift
// ✅ Good: キャッシュされた状態を即座に取得
let status = await subscriptionUseCase.getSubscriptionStatus()

// ✅ Good: サーバーから最新の状態を取得（必要な場合のみ）
let status = try await subscriptionUseCase.checkSubscriptionStatus()

// ❌ Bad: 頻繁にサーバーに問い合わせる
Task {
    while true {
        try await subscriptionUseCase.checkSubscriptionStatus()
        try await Task.sleep(for: .seconds(1))
    }
}
```

### ローディング状態の管理

各Viewが自身のローディング状態を管理することを推奨します：

```swift
struct PurchaseButton: View {
    @State private var isPurchasing = false

    var body: some View {
        Button {
            Task {
                await purchase()
            }
        } label: {
            if isPurchasing {
                ProgressView()
            } else {
                Text("購入する")
            }
        }
        .disabled(isPurchasing)
    }

    private func purchase() async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            _ = try await subscriptionUseCase.purchase(packageId: packageId)
        } catch {
            // エラー処理
        }
    }
}
```

## トラブルシューティング

### APIキーが無効

**症状**: `.notConfigured`エラーが発生
**解決策**: RevenueCat DashboardでAPIキーを確認し、正しく設定されているか確認してください。

### プランが表示されない

**症状**: `loadOfferings()`が`nil`を返す
**解決策**:
1. RevenueCat Dashboardでプランが正しく設定されているか確認
2. App Store Connect / Google Play Consoleでプランが承認されているか確認
3. Sandbox環境でテストしている場合、テストアカウントでログインしているか確認

### 購入がキャンセルされる

**症状**: `.purchaseCancelled`エラーが頻繁に発生
**解決策**: これはユーザーが意図的にキャンセルした場合の正常な動作です。エラーメッセージを表示する必要はありません。

## ライセンス

このパッケージはMITライセンスの下で公開されています。

## サポート

問題が発生した場合や機能リクエストがある場合は、GitHubのIssueを作成してください。
