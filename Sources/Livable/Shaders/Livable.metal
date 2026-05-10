//
//  Livable.metal
//  Livable
//
//  Created by Shindge Wong on 5/10/26.
//  Copyright © 2026 Whatsin Lab. All rights reserved.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

constant float kTau = 6.28318530718;

struct LivableBaseTransformResult {
    float2 uv;
    float alpha;
};

static float2 rotate2D(float2 p, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return float2(p.x * c - p.y * s, p.x * s + p.y * c);
}

static float livableHash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float livableValueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = livableHash21(i);
    float b = livableHash21(i + float2(1.0, 0.0));
    float c = livableHash21(i + float2(0.0, 1.0));
    float d = livableHash21(i + float2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

static float livableFbm(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float2 q = p;

    for (int index = 0; index < 4; ++index) {
        value += livableValueNoise(q) * amplitude;
        q = rotate2D(q * 2.02, 0.58);
        amplitude *= 0.5;
    }

    return value;
}

static float3 sampleLayerUnpremultiplied(
    SwiftUI::Layer layer,
    float2 uv,
    float2 viewOrigin,
    float2 viewSize,
    thread float &alpha
) {
    uv = clamp(uv, float2(0.001), float2(0.999));
    half4 sample = layer.sample(viewOrigin + uv * viewSize);
    alpha = float(sample.a);

    if (sample.a <= 0.0001h) {
        return float3(0.0);
    }

    return float3(sample.rgb / sample.a);
}

static float livableEdgeFade(float2 uv) {
    float2 edgeDistance = min(uv, 1.0 - uv);
    return smoothstep(0.0, 0.075, min(edgeDistance.x, edgeDistance.y));
}

static float livableFootprintAlpha(float2 uv) {
    float2 edgeDistance = min(uv, 1.0 - uv);
    return smoothstep(0.0, 0.012, min(edgeDistance.x, edgeDistance.y));
}

static float2 livableSineField(float2 uv, float time) {
    float waveX = sin((uv.y * 1.35 + time * 0.32) * kTau)
        + sin((dot(uv, float2(0.82, 0.46)) - time * 0.21) * kTau) * 0.55;
    float waveY = cos((uv.x * 1.18 - time * 0.28) * kTau)
        + sin((dot(uv, float2(-0.38, 0.94)) + time * 0.24) * kTau) * 0.50;

    return float2(waveX, waveY) * 0.34;
}

static float2 livableCurlField(float2 uv, float time) {
    float2 p = uv * 1.35 + float2(time * 0.18, -time * 0.13);
    float epsilon = 0.035;
    float left = livableFbm(p - float2(epsilon, 0.0));
    float right = livableFbm(p + float2(epsilon, 0.0));
    float down = livableFbm(p - float2(0.0, epsilon));
    float up = livableFbm(p + float2(0.0, epsilon));
    float2 gradient = float2(right - left, up - down) / (epsilon * 2.0);

    return float2(gradient.y, -gradient.x) * 0.22;
}

static float2 livableFoldField(float2 uv, float time) {
    float2 directionA = normalize(float2(0.82, -0.57));
    float2 directionB = normalize(float2(-0.42, -0.91));
    float2 directionC = normalize(float2(0.18, 0.98));
    float2 normalA = float2(-directionA.y, directionA.x);
    float2 normalB = float2(-directionB.y, directionB.x);
    float2 normalC = float2(-directionC.y, directionC.x);

    float bandA = sin((dot(uv, directionA) * 1.12 + time * 0.16) * kTau);
    float bandB = sin((dot(uv, directionB) * 0.92 - time * 0.13 + 0.31) * kTau);
    float bandC = sin((dot(uv, directionC) * 0.76 + time * 0.10 - 0.22) * kTau);
    float foldA = smoothstep(0.28, 1.0, bandA) * 0.26;
    float foldB = smoothstep(0.34, 1.0, bandB) * 0.20;
    float foldC = smoothstep(0.48, 1.0, bandC) * 0.16;

    return normalA * foldA + normalB * foldB + normalC * foldC;
}

static float2 livableDisplacementPoints(
    float2 uv,
    float time,
    float intensity
) {
    float slowTime = time * 0.45;
    float edge = livableEdgeFade(uv);

    float2 flow = livableSineField(uv, slowTime)
        + livableCurlField(uv, slowTime)
        + livableFoldField(uv, slowTime);

    float flowLength = max(length(flow), 0.001);
    flow = flow / max(flowLength, 1.0);

    float amplitude = mix(0.0, 34.0, intensity) * edge;
    return flow * amplitude;
}

static float3 livableIncreaseSaturation(float3 color, float amount) {
    float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
    return clamp(mix(float3(luma), color, amount), float3(0.0), float3(1.0));
}

/// Lifts contrast around mid-grey by `amount` (1.0 = identity).
static float3 livableApplyContrast(float3 color, float amount) {
    return clamp((color - float3(0.5)) * amount + float3(0.5), float3(0.0), float3(1.0));
}

static float2 livableOffset(float time, float intensity) {
    return float2(
        sin(time * 0.18 + 0.4) * 0.035,
        cos(time * 0.14 - 0.8) * 0.030
    ) * intensity;
}

static float2 livableOverlayOrbitOffset(float time, float intensity, float aspect) {
    float angle = time * 0.20 + 2.4;
    float2 orbit = float2(
        cos(angle) * 0.28 + sin(angle * 0.61 + 1.3) * 0.055,
        sin(angle) * 0.21 + cos(angle * 0.73 - 0.8) * 0.045
    );
    orbit.x /= max(aspect, 0.1);
    return orbit * intensity;
}

static float2 livableApplySwirl(
    float2 uv,
    float2 center,
    float radius,
    float angle,
    float aspect
) {
    float2 p = float2((uv.x - 0.5) * aspect + 0.5, uv.y);
    float2 delta = p - center;
    float distance = length(delta);

    float influence = 1.0 - smoothstep(0.0, radius, distance);
    influence = influence * influence * (3.0 - 2.0 * influence);

    float2 rotated = rotate2D(delta, angle * influence) + center;
    rotated.x = (rotated.x - 0.5) / max(aspect, 0.1) + 0.5;

    return mix(uv, rotated, influence);
}

static float2 livableSwirlUV(float2 uv, float time, float intensity, float aspect) {
    float2 centerA = float2(
        0.48 + sin(time * 0.18) * 0.20,
        0.52 + cos(time * 0.15) * 0.18
    );
    float2 centerB = float2(
        0.62 + cos(time * 0.13 + 1.7) * 0.17,
        0.40 + sin(time * 0.17 + 0.9) * 0.15
    );
    float2 centerC = float2(
        0.30 + cos(time * 0.11 - 0.6) * 0.14,
        0.70 + sin(time * 0.14 + 2.1) * 0.12
    );

    float2 swirledUV = livableApplySwirl(
        uv,
        centerA,
        0.74,
        sin(time * 0.22) * 1.35 * intensity,
        aspect
    );

    swirledUV = livableApplySwirl(
        swirledUV,
        centerB,
        0.58,
        cos(time * 0.19 + 1.2) * -0.92 * intensity,
        aspect
    );

    return livableApplySwirl(
        swirledUV,
        centerC,
        0.42,
        sin(time * 0.16 - 0.9) * 0.58 * intensity,
        aspect
    );
}

static float2 livableSheetWarpUV(float2 uv, float time, float intensity, float aspect) {
    float2 directionA = normalize(float2(0.34, 0.94));
    float2 directionB = normalize(float2(0.88, -0.47));
    float2 normalA = float2(-directionA.y, directionA.x);
    float2 normalB = float2(-directionB.y, directionB.x);

    float bandA = sin((dot(uv, directionA) * 0.70 + time * 0.030 + 0.12) * kTau);
    float bandB = sin((dot(uv, directionB) * 0.58 - time * 0.024 - 0.28) * kTau);
    float sheetA = smoothstep(-0.30, 0.92, bandA);
    float sheetB = smoothstep(-0.18, 0.86, bandB);

    float2 warp = normalA * (sheetA - 0.5) * 0.30
        + normalB * (sheetB - 0.5) * 0.22;
    warp.x /= max(aspect, 0.1);

    return uv + warp * intensity;
}

static LivableBaseTransformResult livableSurfaceTransform(
    float2 uv,
    float time,
    float intensity,
    float visualScale,
    float angleRate,
    float anglePhase,
    float2 offsetBase,
    float2 offsetAmplitude,
    float2 offsetFrequency,
    float offsetPhase
) {
    float2 centered = uv - 0.5;
    float angle = (anglePhase + time * angleRate) * intensity;
    float2 offset = offsetBase + float2(
        sin(time * offsetFrequency.x + offsetPhase) * offsetAmplitude.x,
        cos(time * offsetFrequency.y - offsetPhase * 0.7) * offsetAmplitude.y
    ) * intensity;

    float2 sourceCentered = rotate2D(centered - offset, -angle) / max(visualScale, 0.001);
    float2 transformedUV = sourceCentered + 0.5;

    LivableBaseTransformResult result;
    result.uv = transformedUV;
    result.alpha = livableFootprintAlpha(transformedUV);
    return result;
}

/// Slow base transform applied before displacement.
///
/// Produces a scaled-down, continuously rotating and drifting view of the
/// full source layer. The transform is centered on UV `0.5`, so rotation
/// pivots around the source center.
///
/// - Parameters:
///   - uv: Original normalized UV in `0...1`.
///   - time: Elapsed time in seconds (already pre-scaled by the caller).
///   - intensity: Internal motion amount in `0...1`; current public API fixes this at full strength.
/// - Returns: Transformed UV plus a footprint alpha for pixels outside the scaled source.
static LivableBaseTransformResult livableBaseTransform(float2 uv, float time, float intensity) {
    float2 centered = uv - 0.5;

    // Continuous slow rotation in one direction. The caller passes a reduced
    // base-transform clock so this reads as ambient drift instead of a spin.
    float angle = time * 0.32 * intensity;

    // Coherent positional offset moves the sampled source as one surface.
    float2 offset = livableOffset(time, intensity);

    // Visual scale: the full source layer is rendered into a destination
    // footprint one third of the modified view's size, matching a SwiftUI
    // `scaleEffect(2 / 3)` style transform rather than cropping the source UVs
    // to the center third.
    float visualScale = 2.0 / 3.0;
    float2 sourceCentered = rotate2D(centered - offset, -angle) / max(visualScale, 0.001);
    float2 transformedUV = sourceCentered + 0.5;

    LivableBaseTransformResult result;
    result.uv = transformedUV;
    result.alpha = livableFootprintAlpha(transformedUV);
    return result;
}

/// Samples the source layer at the displaced center UV.
///
/// - Parameters:
///   - layer: SwiftUI source layer to sample from.
///   - uv: Displaced sample center in normalized UV space.
///   - viewOrigin: View origin in layer space.
///   - viewSize: View size in layer space.
///   - alpha: Out parameter receiving the sampled alpha.
/// - Returns: Unpremultiplied RGB from the animated center sample.
static float3 livableCenterSample(
    SwiftUI::Layer layer,
    float2 uv,
    float2 viewOrigin,
    float2 viewSize,
    thread float &alpha
) {
    return sampleLayerUnpremultiplied(layer, uv, viewOrigin, viewSize, alpha);
}

static float3 livableCompositeColor(
    SwiftUI::Layer layer,
    float2 uv,
    float2 viewOrigin,
    float2 viewSize,
    float time,
    thread float &maskAlpha
) {
    uv = clamp(uv, float2(0.0), float2(1.0));
    half4 maskSample = layer.sample(viewOrigin + uv * viewSize);
    maskAlpha = float(maskSample.a);

    float clampedIntensity = 1.0;
    float aspect = viewSize.x / max(viewSize.y, 1.0);
    float2 displacementPoints = livableDisplacementPoints(
        uv,
        time,
        clampedIntensity
    );
    float2 displacementUV = displacementPoints / viewSize;

    LivableBaseTransformResult backgroundTransform = livableSurfaceTransform(
        uv,
        time * 0.16 + 3.4,
        clampedIntensity,
        1.42,
        -0.24,
        0.9,
        float2(0.0, 0.0),
        float2(0.070, 0.060),
        float2(0.10, 0.08),
        2.1
    );
    float2 backgroundUV = livableSwirlUV(
        backgroundTransform.uv,
        time * 0.43 + 4.7,
        clampedIntensity * 0.40,
        aspect
    );
    backgroundUV = livableSheetWarpUV(
        backgroundUV,
        time * 0.31 + 1.6,
        clampedIntensity * 0.42,
        aspect
    );
    backgroundUV += displacementUV * 0.32;

    float backgroundAlpha = 1.0;
    float3 backgroundColor = sampleLayerUnpremultiplied(
        layer,
        backgroundUV,
        viewOrigin,
        viewSize,
        backgroundAlpha
    );

    LivableBaseTransformResult baseTransform = livableBaseTransform(
        uv,
        time * 0.18,
        clampedIntensity
    );

    float2 swirledUV = livableSwirlUV(
        baseTransform.uv,
        time,
        clampedIntensity,
        aspect
    );
    float2 warpedUV = livableSheetWarpUV(
        swirledUV,
        time,
        clampedIntensity,
        aspect
    );

    float2 displacedUV = warpedUV + displacementUV;

    float primaryAlpha = 1.0;
    float3 primaryColor = livableCenterSample(
        layer,
        displacedUV,
        viewOrigin,
        viewSize,
        primaryAlpha
    );
    primaryAlpha *= min(baseTransform.alpha, livableFootprintAlpha(displacedUV));

    float2 primaryCenterOffset = livableOffset(time * 0.18, clampedIntensity);
    float2 overlayOrbitOffset = livableOverlayOrbitOffset(
        time,
        clampedIntensity,
        aspect
    );
    LivableBaseTransformResult overlayTransform = livableSurfaceTransform(
        uv,
        time * 0.27 + 8.2,
        clampedIntensity,
        0.46,
        1.08,
        -1.1,
        primaryCenterOffset + overlayOrbitOffset,
        float2(0.060, 0.050),
        float2(0.15, 0.12),
        5.4
    );
    float2 overlayUV = livableSwirlUV(
        overlayTransform.uv,
        time * 0.74 + 2.3,
        clampedIntensity * 0.90,
        aspect
    );
    overlayUV = livableSheetWarpUV(
        overlayUV,
        time * 0.49 + 7.1,
        clampedIntensity * 0.72,
        aspect
    );
    overlayUV += rotate2D(displacementUV, 0.42) * 0.76;

    float overlayAlpha = 1.0;
    float3 overlayColor = livableCenterSample(
        layer,
        overlayUV,
        viewOrigin,
        viewSize,
        overlayAlpha
    );
    overlayAlpha *= min(overlayTransform.alpha, livableFootprintAlpha(overlayUV));

    float3 color = backgroundColor;
    color = mix(color, primaryColor, clamp(primaryAlpha, 0.0, 1.0));
    color = mix(color, overlayColor, clamp(overlayAlpha, 0.0, 1.0));

    float luminanceWave = sin(
        (dot(uv, normalize(float2(0.74, -0.52))) * 1.05 + time * 0.028) * kTau
    );
    color *= 1.0 + smoothstep(0.45, 1.0, luminanceWave) * 0.035 * clampedIntensity;
    color = livableIncreaseSaturation(color, 1.0 + 0.25 * clampedIntensity);
    return livableApplyContrast(color, 1.0 + 0.18 * clampedIntensity);
}

/// Livable gradient surface.
///
/// Samples the existing SwiftUI layer as three virtual surface layers: a
/// zoomed background fill, a primary layer, and a smaller
/// overlay that orbits around the primary layer center while rotating on its
/// own axis. Each layer uses its own transform clock before swirl, broad sheet
/// warp, and local displacement are applied.
///
/// - Parameters:
///   - position: Current pixel position in layer space.
///   - layer: Source layer to sample from.
///   - bounds: Bounding rect of the view in layer space (`x`, `y`, `width`, `height`).
///   - time: Elapsed time in seconds used to drive slow surface motion.
[[ stitchable ]] half4 livable(
    float2 position,
    SwiftUI::Layer layer,
    float4 bounds,
    float time
) {
    float2 viewOrigin = bounds.xy;
    float2 viewSize = max(bounds.zw, float2(1.0));
    float2 rawUV = (position - viewOrigin) / viewSize;

    // Keep any out-of-bounds invocation transparent to preserve the original
    // silhouette. The SwiftUI modifier currently uses zero maxSampleOffset, but
    // this guard keeps the shader robust if that integration changes later.
    if (any(rawUV < float2(0.0)) || any(rawUV > float2(1.0))) {
        return half4(0.0);
    }

    float2 uv = clamp(rawUV, float2(0.0), float2(1.0));

    float maskAlpha = 1.0;
    float3 color = livableCompositeColor(
        layer,
        uv,
        viewOrigin,
        viewSize,
        time,
        maskAlpha
    );

    return half4(half3(color * maskAlpha), half(maskAlpha));
}
