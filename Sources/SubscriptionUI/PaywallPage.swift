import SwiftUI

/// One screen of a paywall's sales content, drawn entirely by the app.
///
/// This package takes no position on what a page contains — an illustration, a feature list, a
/// testimonial, a video still. It owns the structure around the pages: how they are paged
/// through, and the plans, purchase button, restore button and legal links pinned beneath them.
///
/// ```swift
/// PaywallPage(id: "focus") {
///     VStack(spacing: 16) {
///         Image("focus-illustration").resizable().scaledToFit()
///         Text("Stay in one place").font(.largeTitle.bold())
///     }
/// }
/// ```
///
/// Give more than one page when the app has more than one thing to say. A paywall that carries
/// its argument across several pages converts better than one that crams it into a single
/// screen, and ``PaywallView`` pages through whatever it is given.
public struct PaywallPage: Identifiable {
    /// The page's identity, used to track which page is showing.
    ///
    /// Stable and unique within one paywall. It is a reasonable thing to send to analytics as
    /// the name of the page a purchase happened on.
    public let id: String

    let content: AnyView

    /// Creates a page.
    ///
    /// - Parameters:
    ///   - id: A stable identity, unique within the paywall.
    ///   - content: What the page shows.
    public init<Content: View>(id: String, @ViewBuilder content: () -> Content) {
        self.id = id
        self.content = AnyView(content())
    }
}
