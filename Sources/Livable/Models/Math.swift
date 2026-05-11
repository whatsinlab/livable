//
//  Math.swift
//  Livable
//
//  Created by Shindge Wong on 5/11/26.
//  Copyright © 2026 Whatsin Lab. All rights reserved.
//

import Foundation

/// Generators for deterministic animation parameters.
///
/// The methods in this namespace return index-addressable values, so repeated
/// calls with the same arguments produce the same result.
enum Math {
    /// Returns a golden-ratio additive recurrence value.
    ///
    /// - Parameter index: The sequence position to evaluate.
    /// - Returns: A value in the range `[0, 1)`.
    static func golden(_ index: Int) -> Float {
        let v = Float(index) * .goldenFract
        return v - floor(v)
    }

    /// Returns a base-2 Halton sequence value.
    ///
    /// - Parameter index: The zero-based sequence position to evaluate. Negative
    ///   values are clamped to `0`.
    /// - Returns: A value in the range `[0, 1)`.
    static func halton2(_ index: Int) -> Float {
        var i = UInt32(max(0, index)) + 1
        var result: Float = 0
        var fraction: Float = 0.5
        while i > 0 {
            if i & 1 == 1 { result += fraction }
            i >>= 1
            fraction *= 0.5
        }
        return result
    }

    /// Returns an R2 sequence point in normalized coordinates.
    ///
    /// The method remaps the raw point into the centered region
    /// `[margin, 1 - margin]²`.
    ///
    /// - Parameters:
    ///   - index: The zero-based sequence position to evaluate.
    ///   - margin: The inset to apply to each edge of the unit square.
    /// - Returns: A two-dimensional point in normalized UV space.
    static func r2Point(_ index: Int, margin: Float) -> SIMD2<Float> {
        let raw = SIMD2(Float(index) * .plasticAlpha1, Float(index) * .plasticAlpha2)
        let fract = SIMD2(raw.x - floor(raw.x), raw.y - floor(raw.y))
        let span = 1.0 - 2.0 * margin
        return SIMD2(margin, margin) + fract * span
    }

    /// Returns the linear interpolation between two values.
    ///
    /// - Parameters:
    ///   - lo: The value to return when `t` is `0`.
    ///   - hi: The value to return when `t` is `1`.
    ///   - t: The interpolation amount. Values outside `0...1` extrapolate.
    /// - Returns: The interpolated value.
    static func lerp(_ lo: Float, _ hi: Float, t: Float) -> Float { lo + (hi - lo) * t }
}
