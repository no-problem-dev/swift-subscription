# Subscription

RevenueCat を使ったサブスクリプションとアプリ内課金を、小さな async API で扱う。

![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017.0%2B%20%7C%20macOS%2014.0%2B-blue.svg)
![SPM](https://img.shields.io/badge/SPM-compatible-green.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

[English](./README.md) | 日本語

## 概要

アプリが触るのはストアの型ではなく `SubscriptionUseCase` ひとつ。ペイウォールに必要な
4 つ — 権利の確認、商品の一覧、購入、更新や失効の反映 — をまとめて引き受ける。

- 権利が起動をまたいで残る。圏外のコールドローンチで、払っている人が無料に落ちない
- 端末が知っている読みとサーバー確認を、意図的に別の API として分ける。
  どちらの答えかは値そのものが持つ（規約ではなく型で分かる）
- 購入・復元・ユーザー同期
- 権利の変化を流す `AsyncStream`（アプリが起こしていない変化も届く）
- RevenueCat Paywalls で作ったペイウォールは別プロダクト `SubscriptionRevenueCatUI`。
  自前のペイウォールとの切り替えを一か所で行える
- ペイウォールの骨格は別プロダクト `SubscriptionUI`。請求される実額が常に主表示
- 全体が Sendable。状態は actor が持つ

## 使い方

```swift
import Subscription

let useCase = SubscriptionUseCaseImpl(
    configuration: SubscriptionConfiguration(apiKey: apiKey, entitlementId: "premium"),
    entitlementCache: FileEntitlementCache(url: entitlementFileURL)
)

if try await useCase.checkSubscriptionStatus().isActive {
    unlockPremium()
}
```

`checkSubscriptionStatus()` はストアに問い合わせる。アクセスの可否を決めるならこちらを使う。
`getSubscriptionStatus()` は即座に返る読みで、端末がすでに知っていることを答える。

その「知っていること」はプロセスより長く生きる。ストアが確認できた読みは渡した
`EntitlementCache` に書かれ、ストアに届かない起動は「未加入」からではなくそこから始まる。
期限を過ぎても `gracePeriod` の間は有効で、答えは `.lastKnown(at:)` として返るので、
今ストアが答えたものと区別できる。

```swift
switch status.verification {
case .confirmed:            break   // この起動でストアが答えた
case .lastKnown(let date):  break   // date にストアが言ったことで走っている
case .unverified:           break   // まだ何も分かっていない。「未加入」ではない
}
```

キャッシュに既定値は無い。置き場所はアプリのものだから —— ファイル、App Group の
`UserDefaults`、キーチェーン。`InMemoryEntitlementCache` は降りるための実装で、
その代償は最初の箇条書きのとおり。

## ペイウォール

`SubscriptionUI` は別プロダクト。どのアプリでも同じになる部分だけを持つ。
デザインシステムに依存せず、色・書体・背景は選ばない。

```swift
import SubscriptionUI

PaywallView(
    pages: [PaywallPage(id: "unlock") { UnlockArtwork() }],
    links: PaywallLegalLinks(terms: termsURL, privacy: privacyURL),
    onEntitled: { dismiss() }
)
```

現在のオファリングを読み、年額を先頭に置いて選択済みにし、渡されたページをめくり、
復元ボタンと 2 本の法的リンクを持つ。**請求される実額が各行で最も大きい文字**で、
それを変える引数は無い —— 審査 3.1.2(c) を規約ではなく構造で守る。

### RevenueCat のペイウォールに切り替える

RevenueCatUI に依存するのは `SubscriptionRevenueCatUI` だけ。RevenueCat のダッシュボードで
作ったペイウォールを出し、`PaywallContainer` が `PaywallMode` に従って自前のペイウォールと
どちらを出すかを決める。

| `PaywallMode` | 出るもの |
|---|---|
| `.custom` | 常に自前。RevenueCat には何も問い合わせない |
| `.revenueCat(offering:)` | その offering の RevenueCat ペイウォール（`nil` なら current） |
| `.automatic(offering:)` | offering にダッシュボードでペイウォールが付いていれば RevenueCat、無ければ自前 |

RevenueCat のペイウォールを出せない理由があるとき —— 環境に `SubscriptionUseCase` が無い、
SDK が設定されていない、offering の読み込みに失敗した、指定した offering が無い —— は
自前のペイウォールを出す。

```swift
import SubscriptionRevenueCatUI
import SubscriptionUI

PaywallContainer(
    mode: .automatic,
    onEntitled: { analytics.track(.purchaseCompleted) }
) { handlers in
    NavigationStack {
        PaywallView(
            pages: pages,
            links: links,
            onEntitled: handlers.onEntitled,
            onError: handlers.onError
        )
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる", action: handlers.onDismiss)
            }
        }
    }
}
```

コンテナはどちらのペイウォールにも枠（ナビゲーションバーや閉じるボタン）を付けない。
RevenueCat のペイウォールは閉じるボタンを自分で描くので、ナビゲーションバーと閉じるボタンは
`custom` のクロージャの中に入れ、コンテナ自体はそのままシートに載せる。
`onEntitled` / `onError` / `onDismiss` はどちらのペイウォールでも呼ばれる。自前のほうには
クロージャに渡る `PaywallHandlers` として届く。

`PaywallMode` と、それをどちらを出すかに変える規則（`PaywallMode.choice(for:)`）は
`SubscriptionUI` にある。RevenueCatUI をリンクしないアプリでも設定値として持てる。

## ドキュメント

**[API ドキュメントと Getting Started](https://no-problem-dev.github.io/swift-subscription/documentation/subscription/)**

Getting Started に、前提となる App Store Connect / RevenueCat ダッシュボードの設定、
権利の置き場所の選び方、ペイウォールの作り方、シミュレータでは確認できないことを
まとめてある。

## 必要要件

- iOS 17.0+ / macOS 14.0+
- Swift 6.0+
- [RevenueCat SDK](https://github.com/RevenueCat/purchases-ios) 5.19.0+

## インストール

`Package.swift` に追加する。

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-subscription.git", from: "2.0.0")
]
```

Xcode なら `File > Add Package Dependencies...` に
`https://github.com/no-problem-dev/swift-subscription` を指定する。

## ライセンス

[MIT](./LICENSE)
