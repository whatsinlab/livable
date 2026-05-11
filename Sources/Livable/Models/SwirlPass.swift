//
//  SwirlPass.swift
//  Livable
//
//  Created by Shindge Wong on 5/11/26.
//  Copyright © 2026 Whatsin Lab. All rights reserved.
//

import Foundation

/// One of the three composition passes that Livable layers in the shader.
///
/// Each pass contributes a sample of the source view with its own scale,
/// rotation, and wobble characteristics, while the swirl and sheet warp are
/// now shared across all passes to avoid recomputing per pixel.
enum SwirlPass: Int, CaseIterable {
    /// The zoomed-in backdrop layer.
    case background = 0

    /// The dominant centered layer.
    case primary

    /// The smaller satellite layer that orbits the primary.
    case overlay
}

extension SwirlPass {
    /// The stable integer seed that feeds low-discrepancy generators for this
    /// pass's per-axis parameters.
    var seed: Int { rawValue + 1 }

    /// Multiplier on the shared shader clock for this pass's surface transform.
    var surfaceTimeScale: Float {
        switch self {
        case .background: return 0.16
        case .primary: return 0.18
        case .overlay: return 0.27
        }
    }

    /// Constant phase offset applied to the per-pass surface time.
    var surfaceTimeOffset: Float {
        switch self {
        case .background: return Float.tau * Math.halton2(100)
        case .primary: return 0
        case .overlay: return Float.tau * Math.halton2(102)
        }
    }

    /// Scalar multiplier on the per-pass rotation angle.
    var angleAmplitude: Float {
        switch self {
        case .background: return 0.22
        case .primary: return 0.32
        case .overlay: return 1.0
        }
    }

    /// Returns the effective time argument for this pass.
    ///
    /// - Parameter time: The shared shader time after speed scaling.
    /// - Returns: The pass-specific time argument used to evaluate wobble and
    ///   surface rotation.
    func surfaceTime(time: Float) -> Float { time * surfaceTimeScale + surfaceTimeOffset }
}
