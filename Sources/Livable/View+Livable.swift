//
//  View+Livable.swift
//  Livable
//
//  Created by Shindge Wong on 5/10/26.
//  Copyright © 2026 Whatsin Lab. All rights reserved.
//

import SwiftUI

/// Methods for applying the Livable effect to SwiftUI views.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, *) @available(watchOS, unavailable) extension View {
    /// Applies an animated Livable gradient effect to this view.
    ///
    /// The effect samples the source view as three virtual surface layers: a
    /// zoomed background fill, a primary layer, and a smaller overlay that orbits
    /// the primary layer center. The resulting colors always come from the source
    /// view's pixels.
    ///
    /// The modifier renders inside the modified view's layout bounds. To use the
    /// effect as a full-screen backdrop, give the source view a full-screen frame
    /// at the call site.
    ///
    /// - Parameters:
    ///   - isEnabled: A Boolean value that indicates whether the effect renders.
    ///     The default value is `true`.
    ///   - speed: The motion speed multiplier. The default value is `1`.
    ///   - blurRadius: The post-process blur radius, in points. The default value
    ///     is `64`.
    /// - Returns: A view with the Livable effect applied.
    public func livable(isEnabled: Bool = true, speed: CGFloat = 1, blurRadius: CGFloat = 64) -> some View {
        modifier(LivableViewModifier(isEnabled: isEnabled, blurRadius: blurRadius, speed: speed))
    }
}
