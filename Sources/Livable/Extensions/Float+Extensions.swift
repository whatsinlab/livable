//
//  Float+Extensions.swift
//  Livable
//
//  Created by Shindge Wong on 5/11/26.
//  Copyright © 2026 Whatsin Lab. All rights reserved.
//

import Foundation

/// Constants for Livable's low-discrepancy sequences.
///
/// The Swift animation state generator uses these values to match the constants
/// in the Metal shader.
extension Float {
    /// A full sine cycle, in radians.
    static let tau: Float = 2.0 * .pi

    /// The reciprocal of the golden ratio.
    ///
    /// Livable uses this value as the step size for one-dimensional additive
    /// recurrence sequences.
    static let goldenFract: Float = 0.6180339887498949

    /// The first component of the R2 low-discrepancy sequence.
    ///
    /// This value is `1 / ρ`, where `ρ` is the plastic number.
    static let plasticAlpha1: Float = 0.7548776662466927

    /// The second component of the R2 low-discrepancy sequence.
    ///
    /// This value is `1 / ρ²`, where `ρ` is the plastic number.
    static let plasticAlpha2: Float = 0.5698402909980532
}
