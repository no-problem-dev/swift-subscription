import SwiftUI
import Subscription

/// The list of plans, one selectable row each.
///
/// Rows are drawn in the order given. ``PaywallView`` puts the annual plan first when it loads
/// the offering itself; an app that passes its own list keeps its own order, because the
/// dashboard's order is a decision someone made.
public struct PaywallPlanPicker: View {
    private let packages: [SubscriptionPackage]
    @Binding private var selection: String?
    private let recommendedPackageId: String?
    private let labels: PaywallLabels

    /// Creates a picker.
    ///
    /// - Parameters:
    ///   - packages: The plans to show, in the order to show them.
    ///   - selection: The selected `SubscriptionPackage.id`.
    ///   - recommendedPackageId: The plan to badge, or `nil` to badge none.
    ///   - labels: The words this package puts on screen.
    public init(
        packages: [SubscriptionPackage],
        selection: Binding<String?>,
        recommendedPackageId: String? = nil,
        labels: PaywallLabels = PaywallLabels()
    ) {
        self.packages = packages
        self._selection = selection
        self.recommendedPackageId = recommendedPackageId
        self.labels = labels
    }

    public var body: some View {
        VStack(spacing: 10) {
            ForEach(packages) { package in
                Button {
                    selection = package.id
                } label: {
                    PaywallPlanRow(
                        package: package,
                        isSelected: selection == package.id,
                        badge: package.id == recommendedPackageId ? labels.recommendedBadge : nil,
                        labels: labels
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct PlanPickerPreview: View {
    @State private var selection: String? = "annual"

    var body: some View {
        PaywallPlanPicker(
            packages: SubscriptionOffering.preview.packages,
            selection: $selection,
            recommendedPackageId: "annual"
        )
        .padding()
    }
}

#Preview("Plan picker") {
    PlanPickerPreview()
}
