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
        value = max(value, nextValue())
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

/// Keeps the host `NSWindow` at `height`, holding the top edge fixed so the
/// panel grows and shrinks downwards from the menu bar. SwiftUI animates the
/// card itself; the window simply follows.
struct WindowHeightAdjuster: NSViewRepresentable {
    var height: CGFloat

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            var frame = window.frame
            guard abs(frame.height - height) > 0.5 else { return }
            // Cocoa origin is bottom-left: shift the origin up by the height
            // delta so the top edge stays put.
            frame.origin.y += frame.height - height
            frame.size.height = height
            window.setFrame(frame, display: true)
        }
    }
}
