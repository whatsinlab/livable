//
//  View+Livable.swift
//  Livable
//
//  Created by Shindge Wong on 5/10/26.
//  Copyright © 2026 Whatsin Lab. All rights reserved.
//

import Foundation
import SwiftUI

@available(iOS 17.0, macOS 14.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension View {
    /// Applies a livable gradient effect to the view.
    ///
    /// The effect samples the source view as three virtual surface layers: a zoomed
    /// background fill, a primary layer, and a smaller overlay that orbits the
    /// primary layer center while rotating on its own independently phased axis.
    /// Motion comes from liquid/fabric UV displacement, swirl centers, broad sheet warps,
    /// continuous base rotation, local refraction, post-process blur, and subtle color
    /// treatment. Blur is masked by the original source content, so clipped corners remain
    /// transparent. The colors on screen always come from the source view's pixels; there is
    /// no palette extraction or synthesized gradient.
    /// The modifier renders inside the modified view's own layout bounds. To use it as a
    /// full-screen backdrop, give the source view a full-screen frame at the call site.
    ///
    /// - Parameters:
    ///   - isEnabled: Toggle the effect on or off. Defaults to `true`.
    ///   - speed: Motion speed multiplier. Defaults to `1`.
    ///   - blurRadius: SwiftUI post-process blur radius in points. Defaults to `64`.
    /// - Returns: A view with the livable gradient effect applied.
    public func livable(isEnabled: Bool = true, speed: CGFloat = 1, blurRadius: CGFloat = 64) -> some View {
        modifier(LivableModifier(isEnabled: isEnabled, speed: speed, blurRadius: blurRadius))
    }
}

/// Applies the livable gradient shader to a view.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, *)
@available(watchOS, unavailable)
private struct LivableModifier: ViewModifier {
    @State private var startDate: Date = .init()

    /// Whether the effect should render or pass content through unchanged.
    let isEnabled: Bool

    /// Motion speed multiplier. Values below zero resolve to zero.
    let speed: CGFloat

    /// SwiftUI post-process blur radius in points. Values below zero resolve to zero.
    let blurRadius: CGFloat

    private let shader = ShaderLibrary.bundle(.module).livable
    // The shader always samples within the source view's bounds (UV is
    // clamped to `0...1`), so we do not need SwiftUI to expand the layer's
    // render area. Keeping this at zero prevents generated pixels outside the
    // source silhouette; post-process blur is masked back to the original
    // content to preserve clipped corners.
    private let maxSampleOffset = CGSize.zero

    /// Sanitized values passed into shader and post-processing steps.
    private var resolvedParameters: LivableRenderParameters {
        LivableRenderParameters(speed: max(0, speed), blurRadius: max(0, blurRadius))
    }

    /// Resolves the elapsed shader time passed for a given frame.
    ///
    /// Time is measured from the modifier instance's creation date so the shader receives
    /// stable, small elapsed-second values without wrapping the animation clock.
    ///
    /// - Parameter date: The frame timestamp provided by `TimelineView`.
    /// - Returns: Elapsed seconds since the modifier started rendering.
    private func shaderTime(for date: Date) -> Float { Float(date.timeIntervalSince(startDate)) }

    func body(content: Content) -> some View {
        if isEnabled {
            TimelineView(.animation) { context in
                let parameters = resolvedParameters
                let time = shaderTime(for: context.date)

                content.visualEffect { view, _ in
                    view.layerEffect(
                        shader(.boundingRect, .float(time * Float(parameters.speed))),
                        maxSampleOffset: maxSampleOffset
                    )
                }
                .blur(radius: parameters.blurRadius, opaque: true).mask { content }
            }
        } else {
            content
        }
    }
}

/// Sanitized values forwarded into the livable gradient effect.
private struct LivableRenderParameters: Equatable {
    /// Multiplier applied to elapsed shader time.
    let speed: CGFloat

    /// SwiftUI post-process blur radius in points.
    let blurRadius: CGFloat
}
