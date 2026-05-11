//
//  LivableViewModifier.swift
//  Livable
//
//  Created by Shindge Wong on 5/11/26.
//  Copyright © 2026 Whatsin Lab. All rights reserved.
//

import Foundation
import SwiftUI

/// A view modifier that applies Livable's animated gradient shader.
///
/// The modifier renders the source view through a Metal layer effect, applies an
/// optional blur, and masks the blurred output back to the original content
/// shape.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, *) @available(watchOS, unavailable) struct LivableViewModifier: ViewModifier
{
    /// A Boolean value that indicates whether the effect renders.
    let isEnabled: Bool

    /// The post-process blur radius, in points.
    let blurRadius: CGFloat

    /// The motion speed multiplier.
    let speed: CGFloat

    /// The bundled stitchable Metal shader function.
    private let shader = ShaderLibrary.bundle(.module).livable

    // The shader always samples within the source view's bounds (UV is
    // clamped to `0...1`), so we do not need SwiftUI to expand the layer's
    // render area. Keeping this at zero prevents generated pixels outside the
    // source silhouette; post-process blur is masked back to the original
    // content to preserve clipped corners.
    private let maxSampleOffset = CGSize.zero

    /// The shader phase captured at the most recent speed change.
    @State private var animationPhaseAnchor: Float = 0

    /// The date when the phase anchor was captured.
    @State private var animationPhaseAnchorDate = Date()

    /// The speed active from the current phase anchor.
    @State private var animationPhaseSpeed: CGFloat

    /// Creates a Livable view modifier.
    ///
    /// - Parameters:
    ///   - isEnabled: A Boolean value that indicates whether the shader renders.
    ///   - blurRadius: The post-process blur radius, in points. Values less than
    ///     `0` are clamped to `0`.
    ///   - speed: The motion speed multiplier. Values less than `0` are clamped
    ///     to `0`.
    init(isEnabled: Bool, blurRadius: CGFloat, speed: CGFloat) {
        let clampedSpeed = max(0, speed)
        self.isEnabled = isEnabled
        self.blurRadius = max(0, blurRadius)
        self.speed = clampedSpeed
        self._animationPhaseSpeed = State(initialValue: clampedSpeed)
    }

    /// Returns the body of the modifier.
    ///
    /// - Parameter content: The content to modify.
    /// - Returns: The modified content.
    func body(content: Content) -> some View {
        if isEnabled {
            TimelineView(.animation(paused: speed == 0)) { context in
                let shaderTime = Self.shaderTime(
                    at: context.date,
                    phaseAnchor: animationPhaseAnchor,
                    phaseAnchorDate: animationPhaseAnchorDate,
                    speed: animationPhaseSpeed
                )
                let uniforms = ShaderUniforms.build(time: shaderTime)
                content.visualEffect { view, _ in
                    view.layerEffect(
                        shader(.boundingRect, .float(shaderTime), .floatArray(uniforms)),
                        maxSampleOffset: maxSampleOffset
                    )
                }
                .blur(radius: blurRadius, opaque: true).mask { content }
                .onAppear { reanchorAnimationPhase(at: context.date, nextSpeed: speed) }
                .onChange(of: speed) { reanchorAnimationPhase(at: context.date, nextSpeed: $1) }
            }
        } else {
            content
                .onChange(of: speed) { reanchorAnimationPhase(at: Date(), nextSpeed: $1) }
        }
    }
}

// MARK: - Methods

extension LivableViewModifier {
    /// Returns the shader time for the specified date and speed.
    ///
    /// - Parameters:
    ///   - date: The timeline date for the current frame.
    ///   - phaseAnchor: The shader phase at `phaseAnchorDate`.
    ///   - phaseAnchorDate: The date when `phaseAnchor` was captured.
    ///   - speed: The speed multiplier to apply from the current phase anchor.
    /// - Returns: The effective shader time passed to the Metal shader.
    nonisolated static func shaderTime(at date: Date, phaseAnchor: Float, phaseAnchorDate: Date, speed: CGFloat)
        -> Float
    {
        let elapsed = max(0, date.timeIntervalSince(phaseAnchorDate))
        return phaseAnchor + Float(elapsed) * Float(max(0, speed))
    }

    /// Captures the current phase before a speed change affects future frames.
    ///
    /// - Parameters:
    ///   - date: The timeline date when the speed changed.
    ///   - nextSpeed: The speed value to apply after reanchoring.
    private func reanchorAnimationPhase(at date: Date, nextSpeed: CGFloat) {
        animationPhaseAnchor = Self.shaderTime(
            at: date,
            phaseAnchor: animationPhaseAnchor,
            phaseAnchorDate: animationPhaseAnchorDate,
            speed: animationPhaseSpeed
        )
        animationPhaseAnchorDate = date
        animationPhaseSpeed = max(0, nextSpeed)
    }
}
