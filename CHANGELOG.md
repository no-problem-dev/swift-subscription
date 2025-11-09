# Changelog

このプロジェクトのすべての重要な変更は、このファイルに記録されます。

このフォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) に基づいており、
このプロジェクトは [Semantic Versioning](https://semver.org/lang/ja/) に準拠しています。

## [未リリース]

なし

## [1.0.4] - 2025-11-09

### 修正
- 自動リリースワークフローのメッセージを完全に日本語に統一（PRディスクリプション、リリースノート、ログメッセージ）

## [1.0.3] - 2025-11-04

### 追加
- DocC ドキュメントの自動生成と GitHub Pages への公開機能を追加
  - Swift DocC Plugin を依存関係に追加
  - GitHub Actions ワークフローで自動的にドキュメントを生成・デプロイ
  - README に完全なドキュメントへのリンクを追加 (https://no-problem-dev.github.io/swift-subscription/documentation/subscription/)

### 変更
- ドキュメントへのアクセシビリティを向上

## [1.0.2] - 2025-02-11

### 改善
- README に包括的なセットアップ例とバッジを追加
  - Swift 6.0、プラットフォーム、SPM、ライセンスのバッジを追加
  - 完全なコード例を含むクイックスタートセクションを追加
  - 実際の使用例とエラーハンドリングを追加
  - 各コード例に説明を追加

## [1.0.1] - 2025-02-11

### 追加
- MIT ライセンス情報を含む別の LICENSE ファイルを作成

### 変更
- README から完全なライセンステキストを削除し、LICENSE ファイルへの参照に置き換え

## [1.0.0] - 2024-12-XX

### 追加
- 初回リリース
- RevenueCat 統合
- サブスクリプション状態の確認と監視
- 利用可能なプランの取得
- プランの購入と復元
- ユーザー認証との連携
- SwiftUI 対応（async/await、AsyncStream）
- Actor-based のスレッドセーフな設計
- iOS 17.0+ および macOS 14.0+ サポート

[未リリース]: https://github.com/no-problem-dev/swift-subscription/compare/v1.0.4...HEAD
[1.0.4]: https://github.com/no-problem-dev/swift-subscription/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/no-problem-dev/swift-subscription/compare/v1.0.2...v1.0.3
