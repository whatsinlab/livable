//
//  SwirlConfiguration.swift
//  Livable
//
//  Created by Shindge Wong on 5/11/26.
//  Copyright © 2026 Whatsin Lab. All rights reserved.
//

import Foundation

// These are the only "design knobs" left after switching to mathematical
// generators. Every other parameter is derived from them via low-discrepancy
// sequences (golden ratio, plastic number, Halton base-2).
enum SwirlConfiguration {
    /// Number of swirl centers per pass.
    static let centerCount = 3

    /// Min/max wobble frequency in Hz. Slow values keep the motion ambient.
    static let frequencyRange: (min: Float, max: Float) = (0.11, 0.22)

    /// Min/max wobble radius (UV units). Linear ramp from max to min as center
    /// index grows, so the dominant center wanders furthest.
    static let centerAmplitudeRange: (min: Float, max: Float) = (0.12, 0.20)

    /// Anchors stay at least this far from any UV edge so swirls don't pinch corners.
    static let centerAnchorMargin: Float = 0.25

    /// Maximum swirl angle (radians) for the dominant center; satellites decay by
    /// `φ⁻¹` per index so the strongest swirl always belongs to center 0.
    static let maxSwirlAngle: Float = 1.35

    /// Three swirl centers, fully derived from low-discrepancy sequences:
    /// - Anchors come from the R2 (plastic-number) 2D sequence, kept inside the
    ///   central `[margin, 1 - margin]²` box.
    /// - Frequencies are golden-ratio additive recurrences mapped into the
    ///   tunable Hz range.
    /// - Phases are Halton base-2 mapped to `[0, 2π)`.
    /// - Amplitudes ramp linearly from `max` down to `min` so the dominant center
    ///   wobbles farthest.
    static let centers: [SwirlCenter] = (0..<centerCount)
        .map { i in
            let anchor = Math.r2Point(i + 1, margin: centerAnchorMargin)
            let xIndex = 2 * i
            let yIndex = 2 * i + 1
            let amplitudeT: Float = centerCount > 1 ? Float(i) / Float(centerCount - 1) : 0
            let amplitude = Math.lerp(centerAmplitudeRange.max, centerAmplitudeRange.min, t: amplitudeT)

            return SwirlCenter(
                anchor: anchor,
                x: Oscillator(
                    amplitude: amplitude,
                    frequency: Math.lerp(frequencyRange.min, frequencyRange.max, t: Math.golden(xIndex + 1)),
                    phase: Float.tau * Math.halton2(xIndex)
                ),
                y: Oscillator(
                    amplitude: amplitude,
                    frequency: Math.lerp(frequencyRange.min, frequencyRange.max, t: Math.golden(yIndex + 1)),
                    phase: Float.tau * Math.halton2(yIndex)
                )
            )
        }

    /// Per-center maximum swirl angles. Alternating signs make neighboring centers
    /// counter-rotate, producing the characteristic "fluid pinch" between them.
    /// Magnitudes decay by `φ⁻¹` so center 0 dominates.
    static let angles: [Oscillator] = (0..<centerCount)
        .map { i in
            let index = 2 * centerCount + i
            let sign: Float = (i % 2 == 0) ? 1.0 : -1.0
            let magnitude = maxSwirlAngle * pow(Float.goldenFract, Float(i))

            return Oscillator(
                amplitude: sign * magnitude,
                frequency: Math.lerp(frequencyRange.min, frequencyRange.max, t: Math.golden(index + 1)),
                phase: Float.tau * Math.halton2(index)
            )
        }
}
