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

- キャッシュ読みとサーバー確認を、意図的に別の API として分ける
- 購入・復元・ユーザー同期
- 権利の変化を流す `AsyncStream`（アプリが起こしていない変化も届く）
- 全体が Sendable。キャッシュは actor が持つ

## 使い方

```swift
import Subscription

let useCase = SubscriptionUseCaseImpl(
    configuration: SubscriptionConfiguration(apiKey: apiKey, entitlementId: "premium")
)

if try await useCase.checkSubscriptionStatus().isActive {
    unlockPremium()
}
```

`checkSubscriptionStatus()` はストアに問い合わせる。アクセスの可否を決めるならこちらを使う。
`getSubscriptionStatus()` は即座に返るキャッシュ読みで、初期値は inactive。起動直後の
inactive は「未加入」ではなく「まだ分かっていない」を意味する。

## ドキュメント

**[API ドキュメントと Getting Started](https://no-problem-dev.github.io/swift-subscription/documentation/subscription/)**

Getting Started に、前提となる App Store Connect / RevenueCat ダッシュボードの設定、
ペイウォールの作り方、シミュレータでは確認できないことをまとめてある。

## 必要要件

- iOS 17.0+ / macOS 14.0+
- Swift 6.0+
- [RevenueCat SDK](https://github.com/RevenueCat/purchases-ios) 5.14.0+

## インストール

`Package.swift` に追加する。

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-subscription.git", from: "1.0.4")
]
```

Xcode なら `File > Add Package Dependencies...` に
`https://github.com/no-problem-dev/swift-subscription` を指定する。

## ライセンス

[MIT](./LICENSE)
