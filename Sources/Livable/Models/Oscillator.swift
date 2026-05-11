//
//  Oscillator.swift
//  Livable
//
//  Created by Shindge Wong on 5/11/26.
//  Copyright © 2026 Whatsin Lab. All rights reserved.
//

import Foundation

/// A sinusoidal source of one-dimensional motion.
///
/// An oscillator evaluates `amplitude * sin(time * frequency + phase)`.
struct Oscillator {
    /// The maximum distance from the neutral value.
    let amplitude: Float

    /// The angular rate applied to shader time.
    let frequency: Float

    /// The constant phase offset, in radians.
    let phase: Float
}

extension Oscillator {
    /// Returns the oscillator value at the specified time.
    ///
    /// - Parameter time: The effective shader time for the current frame.
    /// - Returns: The signed displacement at `time`.
    func value(time: Float) -> Float { amplitude * sin(time * frequency + phase) }
}
