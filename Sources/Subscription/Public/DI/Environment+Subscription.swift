import SwiftUI

/// SubscriptionUseCase用の環境値キー
public struct SubscriptionUseCaseKey: EnvironmentKey {
    public static var defaultValue: SubscriptionUseCase? {
        nil
    }
}

public extension EnvironmentValues {
    /// サブスクリプションユースケースの環境値
    ///
    /// 使用例:
    /// ```swift
    /// @Environment(\.subscriptionUseCase) private var subscriptionUseCase
    /// ```
    var subscriptionUseCase: SubscriptionUseCase? {
        get { self[SubscriptionUseCaseKey.self] }
        set { self[SubscriptionUseCaseKey.self] = newValue }
    }
}

/// SubscriptionUseCaseを注入するためのViewModifier
///
/// パッケージ境界を越えて環境値を確実に伝播させます。
/// 通常は`View.subscriptionUseCase(_:)`メソッド経由で使用します。
public struct SubscriptionUseCaseModifier: ViewModifier {
    private let subscriptionUseCase: SubscriptionUseCase

    public init(subscriptionUseCase: SubscriptionUseCase) {
        self.subscriptionUseCase = subscriptionUseCase
    }

    public func body(content: Content) -> some View {
        content
            .environment(\.subscriptionUseCase, subscriptionUseCase)
    }
}

public extension View {
    /// SubscriptionUseCaseを注入する
    ///
    /// - Parameter subscriptionUseCase: 使用するSubscriptionUseCaseインスタンス
    /// - Returns: SubscriptionUseCaseが注入されたView
    ///
    /// 使用例:
    /// ```swift
    /// let subscriptionConfig = SubscriptionConfiguration(
    ///     apiKey: revenueCatAPIKey
    /// )
    /// let subscriptionUseCase = SubscriptionUseCaseImpl(
    ///     configuration: subscriptionConfig
    /// )
    /// ContentView()
    ///     .subscriptionUseCase(subscriptionUseCase)
    /// ```
    func subscriptionUseCase(_ subscriptionUseCase: SubscriptionUseCase) -> some View {
        modifier(SubscriptionUseCaseModifier(subscriptionUseCase: subscriptionUseCase))
    }
}
