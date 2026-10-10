//
//  AdaptivePanel.swift
//  boringNotch
//
//  SPDX-License-Identifier: GPL-3.0-only
//
//  Shell plumbing for the content-adaptive panel: page height measurement and
//  keeping the host NSWindow sized to the panel, top-anchored.
//

import SwiftUI

/// Carries the rendered height of the open notch content up the view tree so
/// the shell can size the panel to whatever page is showing.
struct PageHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 {
            value = next
        }
    }
}

extension View {
    /// Publishes this view's rendered height to `PageHeightPreferenceKey`.
    /// Attach before any height-restricting frame so the natural height is
    /// measured rather than the clamped one.
    func measuresPageHeight() -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: PageHeightPreferenceKey.self, value: proxy.size.height)
            }
        )
    }
}

/// Subclass that guarantees the host NSWindow is resized whenever the view moves
/// to a window or whenever the target height changes.
final class WindowHeightAdjustingView: NSView {
    var targetHeight: CGFloat = 0 {
        didSet {
            applyHeight()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyHeight()
    }

    func applyHeight() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window, self.targetHeight > 0 else { return }
            var frame = window.frame
            guard abs(frame.height - self.targetHeight) > 0.5 else { return }
            // Cocoa origin is bottom-left: shift the origin up by the height
            // delta so the top edge stays put.
            frame.origin.y += frame.height - self.targetHeight
            frame.size.height = self.targetHeight
            window.setFrame(frame, display: true)
        }
    }
}

/// Keeps the host NSWindow at height, holding the top edge fixed so the
/// panel grows and shrinks downwards from the menu bar. SwiftUI animates the
/// card itself; the window simply follows.
struct WindowHeightAdjuster: NSViewRepresentable {
    var height: CGFloat

    func makeNSView(context: Context) -> WindowHeightAdjustingView {
        let view = WindowHeightAdjustingView(frame: .zero)
        view.targetHeight = height
        return view
    }

    func updateNSView(_ nsView: WindowHeightAdjustingView, context: Context) {
        nsView.targetHeight = height
    }
}
