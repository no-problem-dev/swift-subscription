import SwiftUI
import Subscription

/// One plan, laid out so the amount the customer will actually be charged is the largest thing
/// in the row.
///
/// ## Why the type has no font parameters
///
/// App Store Review 3.1.2(c) rejects a paywall whose most prominent price is not the one that
/// will be billed — the classic version being an annual plan headlined "¥500/month" with
/// "¥6,000/year" tucked underneath in grey. The rule is easy to agree with and easy to violate
/// by accident, so it is enforced by construction here rather than by documentation:
///
/// - The only text this row will render large is `SubscriptionPackage.price`, which is the
///   billed amount as the store formatted it.
/// - `SubscriptionPackage.pricePerMonth` is rendered at caption size, in secondary colour,
///   with ``PaywallLabels/perMonthSuffix`` attached — and only when the store supplied one,
///   which it does only for annual packages.
/// - A free trial is a caption line under the title, from ``PaywallLabels/freeTrial``, and only
///   when the customer is eligible for it. The price stays the amount charged when it ends.
/// - There is no parameter for a font, a size, or an alternative headline. An app that wants a
///   different arrangement has to write its own row, at which point it is making the choice
///   deliberately rather than inheriting a rejection.
///
/// The fonts are set explicitly on each `Text`, so a `.font()` applied from outside does not
/// reach in and shrink the price.
public struct PaywallPlanRow: View {
    private let package: SubscriptionPackage
    private let isSelected: Bool
    private let badge: String?
    private let labels: PaywallLabels

    /// Creates a row.
    ///
    /// - Parameters:
    ///   - package: The plan, as it came from `SubscriptionUseCase.loadOfferings()`. Every
    ///     string it shows is the store's, already localized and currency-formatted.
    ///   - isSelected: Whether this is the plan the purchase button will buy.
    ///   - badge: A short label such as "Best value", or `nil` for none.
    ///   - labels: The words this package puts on screen.
    public init(
        package: SubscriptionPackage,
        isSelected: Bool,
        badge: String? = nil,
        labels: PaywallLabels = PaywallLabels()
    ) {
        self.package = package
        self.isSelected = isSelected
        self.badge = badge
        self.labels = labels
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(package.title)
                        .font(.subheadline.weight(.medium))
                    if let badge {
                        BadgeLabel(text: badge)
                    }
                }

                // Only for someone the store will give the trial to. Anyone else is charged the
                // price on the right today.
                if let offer = package.introductoryOffer, offer.isEligibleFreeTrial {
                    Text(labels.freeTrial(offer.duration))
                        .font(.caption.weight(.semibold))
                }

                // The derived figure, never the headline.
                if let pricePerMonth = package.pricePerMonth {
                    Text("\(pricePerMonth) \(labels.perMonthSuffix)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            // The amount that will be charged. The largest text in the row, always.
            Text(package.price)
                .font(.title3.weight(.bold))
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: 64)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.secondary.opacity(0.3),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct BadgeLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.accentColor.opacity(0.15), in: Capsule())
    }
}

#Preview("Plan rows") {
    VStack(spacing: 12) {
        PaywallPlanRow(
            package: SubscriptionOffering.preview.packages[0],
            isSelected: true,
            badge: "Best value"
        )
        PaywallPlanRow(
            package: SubscriptionOffering.preview.packages[1],
            isSelected: false
        )
    }
    .padding()
}
