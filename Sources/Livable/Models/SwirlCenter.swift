//
//  SwirlCenter.swift
//  Livable
//
//  Created by Shindge Wong on 5/11/26.
//  Copyright © 2026 Whatsin Lab. All rights reserved.
//

import Foundation

/// A moving swirl center in normalized UV space.
struct SwirlCenter {
    /// The neutral center position.
    let anchor: SIMD2<Float>

    /// The oscillator that controls horizontal movement.
    let x: Oscillator

    /// The oscillator that controls vertical movement.
    let y: Oscillator
}

extension SwirlCenter {
    /// Returns the center position at the specified time.
    ///
    /// - Parameter time: The effective shader time for the current frame.
    /// - Returns: The animated center position in normalized UV space.
    func position(time: Float) -> SIMD2<Float> { anchor + SIMD2(x.value(time: time), y.value(time: time)) }
}
