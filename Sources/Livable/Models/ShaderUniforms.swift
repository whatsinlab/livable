//
//  ShaderUniforms.swift
//  Livable
//
//  Created by Shindge Wong on 5/11/26.
//  Copyright © 2026 Whatsin Lab. All rights reserved.
//

import Foundation

/// Builds the per-frame uniform buffer that the Livable shader consumes.
///
/// All time-only sinusoids that the shader previously evaluated per pixel are
/// pre-computed on the CPU once per frame and packed into a single `Float`
/// buffer:
///
/// - `[0..6)`   Three swirl centers (`float2` each) in UV space.
/// - `[6..9)`   Three swirl rotation angles, in radians.
/// - `[9..15)`  Three surface-pass wobble offsets (`float2` each), ordered
///   background, primary, overlay. The overlay wobble includes the primary
///   offset so it can orbit the primary layer.
/// - `[15..21)` Three surface-pass rotation terms (`(cos, sin)` pairs),
///   ordered background, primary, overlay.
/// - `[21..23)` The overlay orbit offset before shader-side aspect correction.
enum ShaderUniforms {
    /// The number of `Float` elements the shader expects.
    static let floatCount = 23

    /// Returns the packed uniform buffer for the supplied shader time.
    static func build(time: Float) -> [Float] {
        var values: [Float] = []
        values.reserveCapacity(floatCount)
        appendSwirl(into: &values, time: time)
        let orbit = appendSurfaceOffsets(into: &values, time: time)
        appendSurfaceRotations(into: &values, time: time)
        append(into: &values, vector: orbit)
        return values
    }

    private static func appendSwirl(into values: inout [Float], time: Float) {
        for center in SwirlConfiguration.centers {
            let position = center.position(time: time)
            values.append(position.x)
            values.append(position.y)
        }
        for angle in SwirlConfiguration.angles { values.append(angle.value(time: time)) }
    }

    private static func appendSurfaceOffsets(into values: inout [Float], time: Float) -> SIMD2<Float> {
        let backgroundWobble = wobble(
            seed: SwirlPass.background.seed,
            time: SwirlPass.background.surfaceTime(time: time)
        )
        let primaryWobble = wobble(seed: SwirlPass.primary.seed, time: SwirlPass.primary.surfaceTime(time: time))
        let overlayWobble = wobble(seed: SwirlPass.overlay.seed, time: SwirlPass.overlay.surfaceTime(time: time))
        let orbit = overlayOrbit(time: time)
        let overlayOffset = primaryWobble + overlayWobble

        append(into: &values, vector: backgroundWobble)
        append(into: &values, vector: primaryWobble)
        append(into: &values, vector: overlayOffset)
        return orbit
    }

    private static func appendSurfaceRotations(into values: inout [Float], time: Float) {
        for pass in SwirlPass.allCases {
            let angle = surfaceAngle(pass: pass, time: time)
            values.append(cos(angle))
            values.append(sin(angle))
        }
    }

    private static func wobble(seed: Int, time: Float) -> SIMD2<Float> {
        let fx = Math.lerp(0.12, 0.22, t: Math.golden(seed * 2 + 1))
        let fy = Math.lerp(0.12, 0.22, t: Math.golden(seed * 2 + 3))
        let px = Math.halton2(seed * 2) * .tau
        let py = Math.halton2(seed * 2 + 1) * .tau
        let ax = Math.lerp(0.025, 0.040, t: Math.golden(seed * 2 + 5))
        let ay = Math.lerp(0.025, 0.040, t: Math.golden(seed * 2 + 7))
        return SIMD2(sin(time * fx + px) * ax, sin(time * fy + py) * ay)
    }

    private static func overlayOrbit(time: Float) -> SIMD2<Float> {
        let rate = OverlayOrbit.rate
        let secondaryStrength = OverlayOrbit.secondaryStrength

        let ax = time * rate + OverlayOrbit.primaryPhaseX
        let ay = time * rate * .goldenFract + OverlayOrbit.primaryPhaseY
        let primary = SIMD2(cos(ax), sin(ay))

        let secondaryRate = rate * .goldenFract * .goldenFract
        let sx = time * secondaryRate + OverlayOrbit.secondaryPhaseX
        let sy = time * secondaryRate * .goldenFract + OverlayOrbit.secondaryPhaseY
        let secondary = SIMD2(sin(sx), cos(sy))

        let norm: Float = 1.0 / (1.0 + secondaryStrength)
        let orbit = (primary + secondary * secondaryStrength) * norm
        return orbit * OverlayOrbit.halfExtent
    }

    private static func surfaceAngle(pass: SwirlPass, time: Float) -> Float {
        let passTime = pass.surfaceTime(time: time)
        let anglePhase = Math.halton2(pass.seed * 7) * .tau
        let angleRate = (Math.golden(pass.seed * 7 + 1) * 2 - 1) * 1.1
        return (anglePhase + passTime * angleRate) * pass.angleAmplitude
    }

    private static func append(into values: inout [Float], vector: SIMD2<Float>) {
        values.append(vector.x)
        values.append(vector.y)
    }
}

private enum OverlayOrbit {
    static let rate: Float = 0.20
    static let secondaryStrength: Float = 0.45
    static let halfExtent = SIMD2<Float>(0.50, 0.50)
    static let primaryPhaseX: Float = 0.578125 * .tau
    static let primaryPhaseY: Float = 0.328125 * .tau
    static let secondaryPhaseX: Float = 0.828125 * .tau
    static let secondaryPhaseY: Float = 0.203125 * .tau
}
