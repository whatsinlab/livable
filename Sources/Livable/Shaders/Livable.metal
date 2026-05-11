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

// MARK: - Mathematical constants

constant float kTau = 6.28318530718;
constant float kGoldenFract = 0.6180339887498949;
constant float kPlasticAlpha1 = 0.7548776662466927;
constant float kPlasticAlpha2 = 0.5698402909980532;
constant int kUniformFloatCount = 21;

// MARK: - Low-discrepancy generators

static float lvGolden(int index) {
    float v = float(index) * kGoldenFract;
    return v - floor(v);
}

static float lvHalton2(int index) {
    uint i = uint(max(index, 0)) + 1u;
    float result = 0.0;
    float fraction = 0.5;
    while (i > 0u) {
        if ((i & 1u) == 1u) { result += fraction; }
        i >>= 1u;
        fraction *= 0.5;
    }
    return result;
}

static float2 lvR2(int index) {
    float a = float(index) * kPlasticAlpha1;
    float b = float(index) * kPlasticAlpha2;
    return float2(a - floor(a), b - floor(b));
}

static float lvLerp(float lo, float hi, float t) {
    return lo + (hi - lo) * t;
}

static float lvGoldenSigned(int index) {
    return lvGolden(index) * 2.0 - 1.0;
}

static float2 lvUnitFromIndex(int index) {
    float angle = lvHalton2(index) * kTau;
    return float2(cos(angle), sin(angle));
}

// MARK: - Math helpers

static float2 rotate2D(float2 p, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return float2(p.x * c - p.y * s, p.x * s + p.y * c);
}

/// Rotates `p` using a precomputed `(cos(angle), sin(angle))` pair.
static float2 rotateByCosSin(float2 p, float2 cs) {
    return float2(p.x * cs.x - p.y * cs.y, p.x * cs.y + p.y * cs.x);
}

static float livableHash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

/// Value noise with analytic gradient. Returns `(value, ∂x, ∂y)`.
static float3 livableValueNoiseD(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float2 du = 6.0 * f * (1.0 - f);

    float a = livableHash21(i);
    float b = livableHash21(i + float2(1.0, 0.0));
    float c = livableHash21(i + float2(0.0, 1.0));
    float d = livableHash21(i + float2(1.0, 1.0));

    float k = a - b - c + d;
    float value = a + (b - a) * u.x + (c - a) * u.y + k * u.x * u.y;
    float dx = du.x * ((b - a) + k * u.y);
    float dy = du.y * ((c - a) + k * u.x);

    return float3(value, dx, dy);
}

/// Four-octave fbm with analytic gradient via Jacobian tracking.
static float3 livableFbmD(float2 p) {
    const float lacunarity = 2.0;
    const float octaveRotation = kGoldenFract;
    const float gain = 0.5;
    const float c = cos(octaveRotation);
    const float s = sin(octaveRotation);
    const float2x2 M = float2x2(
        float2(lacunarity * c, lacunarity * s),
        float2(-lacunarity * s, lacunarity * c)
    );

    float value = 0.0;
    float2 grad = float2(0.0);
    float amplitude = 0.5;
    float2 q = p;
    float2x2 jac = float2x2(float2(1.0, 0.0), float2(0.0, 1.0));

    for (int index = 0; index < 4; ++index) {
        float3 nd = livableValueNoiseD(q);
        value += nd.x * amplitude;
        grad += amplitude * (transpose(jac) * float2(nd.y, nd.z));

        q = rotate2D(q * lacunarity, octaveRotation);
        jac = M * jac;
        amplitude *= gain;
    }

    return float3(value, grad);
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

// MARK: - Surface fields

constant float2 kFieldSpaceFreqRange = float2(0.55, 1.40);
constant float kFieldTimeRateMax = 0.34;
constant float kFieldAmplitudeDecay = kGoldenFract;

static float2 livableDirectionalField(
    float2 uv,
    float time,
    int termCount,
    int seed,
    float rectifyEdge
) {
    float2 sum = float2(0.0);
    float amplitude = 1.0;
    for (int i = 0; i < termCount; ++i) {
        int k = seed + i;
        float2 dir = lvUnitFromIndex(k * 3);
        float2 normal = float2(-dir.y, dir.x);
        float spaceFreq = lvLerp(
            kFieldSpaceFreqRange.x,
            kFieldSpaceFreqRange.y,
            lvGolden(k * 3 + 1)
        );
        float timeRate = lvGoldenSigned(k * 3 + 2) * kFieldTimeRateMax;
        float phase = lvHalton2(k * 3 + 2) * kTau;
        float band = sin((dot(uv, dir) * spaceFreq + time * timeRate + phase) * kTau);
        float contribution = (rectifyEdge >= 0.0)
            ? smoothstep(rectifyEdge, 1.0, band)
            : band;
        sum += normal * contribution * amplitude;
        amplitude *= kFieldAmplitudeDecay;
    }
    return sum;
}

static float2 livableSineField(float2 uv, float time) {
    return livableDirectionalField(uv, time, 4, 0, -1.0) * 0.34;
}

static float2 livableFoldField(float2 uv, float time) {
    return livableDirectionalField(uv, time, 3, 16, 0.30) * 0.62;
}

static float2 livableCurlField(float2 uv, float time) {
    float2 drift = (lvR2(11) - 0.5) * 0.36;
    float2 p = uv * 1.35 + drift * time;
    float3 nd = livableFbmD(p);
    return float2(nd.z, -nd.y) * 0.22;
}

static float2 livableDisplacementPoints(float2 uv, float time) {
    float slowTime = time * 0.45;
    float edge = livableEdgeFade(uv);

    float2 flow = livableSineField(uv, slowTime)
        + livableCurlField(uv, slowTime)
        + livableFoldField(uv, slowTime);

    float flowLength = max(length(flow), 0.001);
    flow = flow / max(flowLength, 1.0);

    float amplitude = 34.0 * edge;
    return flow * amplitude;
}

static float3 livableIncreaseSaturation(float3 color, float amount) {
    float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
    return clamp(mix(float3(luma), color, amount), float3(0.0), float3(1.0));
}

static float3 livableApplyContrast(float3 color, float amount) {
    return clamp((color - float3(0.5)) * amount + float3(0.5), float3(0.0), float3(1.0));
}

// MARK: - Shared swirl + sheet warp
//
// These passes used to be applied separately per surface layer. Sharing them
// at the raw-UV level reduces the per-pixel cost from three swirl + three
// sheet-warp evaluations to one of each.

/// Rotates `uv` around a single swirl center if the pixel falls inside the
/// swirl's radius. Pixels outside the radius bypass the rotation entirely so
/// they never pay for the `sqrt` inside `length`.
static float2 livableApplySwirl(
    float2 uv,
    float2 center,
    float radius,
    float angle,
    float aspect
) {
    float2 p = float2((uv.x - 0.5) * aspect + 0.5, uv.y);
    float2 delta = p - center;
    float distanceSquared = dot(delta, delta);
    float radiusSquared = radius * radius;

    if (distanceSquared >= radiusSquared) {
        return uv;
    }

    float distance = sqrt(distanceSquared);
    float influence = 1.0 - smoothstep(0.0, radius, distance);
    influence = influence * influence * (3.0 - 2.0 * influence);

    float2 rotated = rotate2D(delta, angle * influence) + center;
    rotated.x = (rotated.x - 0.5) / max(aspect, 0.1) + 0.5;

    return mix(uv, rotated, influence);
}

/// Reads the swirl state from the uniform buffer and applies the three swirl
/// centers as a single shared pass.
static float2 livableSwirlUV(float2 uv, device const float *uniforms, float aspect) {
    float2 centerA = float2(uniforms[0], uniforms[1]);
    float2 centerB = float2(uniforms[2], uniforms[3]);
    float2 centerC = float2(uniforms[4], uniforms[5]);

    float2 swirledUV = livableApplySwirl(uv, centerA, 0.74, uniforms[6], aspect);
    swirledUV = livableApplySwirl(swirledUV, centerB, 0.58, uniforms[7], aspect);
    return livableApplySwirl(swirledUV, centerC, 0.42, uniforms[8], aspect);
}

constant float kSheetSpaceFreqMin = 0.55;
constant float kSheetSpaceFreqMax = 0.78;
constant float kSheetTimeRateMax = 0.034;
constant float kSheetWarpStrength = 0.30;

static float2 livableSheetWarpUV(float2 uv, float time, float aspect, int seed) {
    const int termCount = 2;
    float2 warp = float2(0.0);
    float amplitude = 1.0;
    for (int i = 0; i < termCount; ++i) {
        int k = seed + i;
        float2 dir = lvUnitFromIndex(k * 5);
        float2 normal = float2(-dir.y, dir.x);
        float spaceFreq = lvLerp(kSheetSpaceFreqMin, kSheetSpaceFreqMax, lvGolden(k * 5 + 1));
        float timeRate = lvGoldenSigned(k * 5 + 2) * kSheetTimeRateMax;
        float phase = lvHalton2(k * 5 + 3) * kTau;
        float band = sin((dot(uv, dir) * spaceFreq + time * timeRate + phase) * kTau);
        float sheet = smoothstep(-0.24, 0.90, band);
        warp += normal * (sheet - 0.5) * amplitude;
        amplitude *= kFieldAmplitudeDecay;
    }
    warp *= kSheetWarpStrength;
    warp.x /= max(aspect, 0.1);
    return uv + warp;
}

// MARK: - Per-pass surface transform

/// Parameters describing one of the three composition passes. Both the
/// translation offset and the rotation `(cos, sin)` pair are precomputed on
/// the CPU so the shader never evaluates a time-only sin/cos at this layer.
struct LivableSurfaceParams {
    float scale;
    float2 offset;
    float2 rotationCosSin;
};

/// Applies the pass's centered scale and rotation to a shared input UV.
///
/// The original implementation called `rotate2D(p, -angle)`. With a
/// precomputed `(cos(angle), sin(angle))` pair, the inverse rotation is
/// `rotateByCosSin(p, float2(cos, -sin))`.
static float2 livableSurfaceTransformUV(float2 uv, LivableSurfaceParams params) {
    float2 centered = uv - 0.5;
    float2 shifted = centered - params.offset;
    float2 inverseCosSin = float2(params.rotationCosSin.x, -params.rotationCosSin.y);
    float2 rotated = rotateByCosSin(shifted, inverseCosSin);
    return rotated / max(params.scale, 0.001) + 0.5;
}

// MARK: - Composite

constant float kBackgroundScale = 1.42;
constant float kPrimaryScale    = 2.0 / 3.0;
constant float kOverlayScale    = 0.46;

static float3 livableCompositeColor(
    SwiftUI::Layer layer,
    float2 uv,
    float2 viewOrigin,
    float2 viewSize,
    float time,
    device const float *uniforms,
    thread float &maskAlpha
) {
    uv = clamp(uv, float2(0.0), float2(1.0));

    // The mask alpha is the source layer's own alpha at this raw UV. It is
    // emitted into the output's alpha channel so the rectangle the shader
    // fills follows the source's silhouette (e.g. rounded corners) — without
    // this, the `.blur(opaque: true)` outside the shader reads off-layer
    // pixels at the view's four edges as `rgb = 0` and renders a thin black
    // band there. Premultiplying the shader color with this alpha also keeps
    // the blurred fade-out in the silhouette's transparent margin, where the
    // outer `.mask { content }` already discards it.
    half4 maskSample = layer.sample(viewOrigin + uv * viewSize);
    maskAlpha = float(maskSample.a);

    float aspect = viewSize.x / max(viewSize.y, 1.0);

    float2 displacementPoints = livableDisplacementPoints(uv, time);
    float2 displacementUV = displacementPoints / viewSize;

    // Per-pass surface transforms read precomputed offsets and rotations.
    LivableSurfaceParams backgroundParams = {
        kBackgroundScale,
        float2(uniforms[9], uniforms[10]),
        float2(uniforms[15], uniforms[16])
    };
    LivableSurfaceParams primaryParams = {
        kPrimaryScale,
        float2(uniforms[11], uniforms[12]),
        float2(uniforms[17], uniforms[18])
    };
    LivableSurfaceParams overlayParams = {
        kOverlayScale,
        float2(uniforms[13], uniforms[14]),
        float2(uniforms[19], uniforms[20])
    };

    // Shared swirl + sheet warp at raw UV is reused by the primary and
    // overlay passes (whose footprints already discard out-of-source UVs).
    float2 swirledUV = livableSwirlUV(uv, uniforms, aspect);
    float2 sharedUV = livableSheetWarpUV(swirledUV, time, aspect, /* seed */ 60);

    // Background runs its own swirl + warp on its already-contracted UV
    // (`scale = 1.42` keeps `bgBaseUV` inside `[~0.15, 0.85]`).
    float2 bgBaseUV = livableSurfaceTransformUV(uv, backgroundParams);
    float2 bgSwirledUV = livableSwirlUV(bgBaseUV, uniforms, aspect);
    float2 backgroundUV = livableSheetWarpUV(bgSwirledUV, time, aspect, /* seed */ 50)
        + displacementUV * 0.32;

    // Safety clamp: the stacked swirl + warp + displacement can still push the
    // bg UV past the source layer's rounded-corner alpha-falloff zone (the bg
    // pass uses the shared swirl angles, which are stronger than the original
    // per-pass scaled angles). Without this clamp, those pixels fetch from a
    // fully-transparent source location and `sampleLayerUnpremultiplied`
    // returns `float3(0)` — producing the black wedges we saw at the view's
    // bottom-left corner. The `[0.15, 0.85]` window matches the bg's natural
    // unrotated range and is safely inside the opaque interior of any source
    // layer whose corners round inward by less than ~22%.
    backgroundUV = clamp(backgroundUV, float2(0.15), float2(0.85));

    float2 primaryBaseUV = livableSurfaceTransformUV(sharedUV, primaryParams);
    float2 primaryUV = primaryBaseUV + displacementUV;
    float primaryFootprint = min(
        livableFootprintAlpha(primaryBaseUV),
        livableFootprintAlpha(primaryUV)
    );

    float2 overlayBaseUV = livableSurfaceTransformUV(sharedUV, overlayParams);
    float2 overlayUV = overlayBaseUV + rotate2D(displacementUV, kGoldenFract) * 0.76;
    float overlayFootprint = min(
        livableFootprintAlpha(overlayBaseUV),
        livableFootprintAlpha(overlayUV)
    );

    // Sample primary/overlay only when their footprints can contribute. The
    // composite alpha keeps the source layer's alpha so transparent regions of
    // the source fall through to the background instead of producing black.
    float primaryAlpha = 0.0;
    float3 primaryColor = float3(0.0);
    if (primaryFootprint > 0.0) {
        float sourceAlpha = 0.0;
        primaryColor = sampleLayerUnpremultiplied(
            layer, primaryUV, viewOrigin, viewSize, sourceAlpha
        );
        primaryAlpha = sourceAlpha * primaryFootprint;
    }

    float overlayAlpha = 0.0;
    float3 overlayColor = float3(0.0);
    if (overlayFootprint > 0.0) {
        float sourceAlpha = 0.0;
        overlayColor = sampleLayerUnpremultiplied(
            layer, overlayUV, viewOrigin, viewSize, sourceAlpha
        );
        overlayAlpha = sourceAlpha * overlayFootprint;
    }

    // Skip the background fetch only when the primary already fully covers the
    // pixel and the source isn't transparent there.
    float3 backgroundColor = float3(0.0);
    if (primaryAlpha < 1.0) {
        float sourceAlpha = 0.0;
        backgroundColor = sampleLayerUnpremultiplied(
            layer, backgroundUV, viewOrigin, viewSize, sourceAlpha
        );
    }

    float3 color = backgroundColor;
    color = mix(color, primaryColor, clamp(primaryAlpha, 0.0, 1.0));
    color = mix(color, overlayColor, clamp(overlayAlpha, 0.0, 1.0));

    float lumAngle = lvHalton2(200) * kTau;
    float2 lumDir = float2(cos(lumAngle), sin(lumAngle));
    float luminanceWave = sin((dot(uv, lumDir) * 1.05 + time * 0.028) * kTau);
    color *= 1.0 + smoothstep(0.45, 1.0, luminanceWave) * 0.035;
    color = livableIncreaseSaturation(color, 1.25);
    return livableApplyContrast(color, 1.18);
}

[[ stitchable ]] half4 livable(
    float2 position,
    SwiftUI::Layer layer,
    float4 bounds,
    float time,
    device const float *uniforms,
    int uniformCount
) {
    if (uniforms == nullptr || uniformCount < kUniformFloatCount) {
        return half4(0.0);
    }

    float2 viewOrigin = bounds.xy;
    float2 viewSize = max(bounds.zw, float2(1.0));
    // Clamp instead of early-returning transparent for subpixel-outside-bounds
    // positions: at the four view edges, anti-aliased pixel centers can fall a
    // hair past `[0, 1]`, and returning `half4(0)` there leaves a 1px black
    // gap between the rendered content and the view frame.
    float2 uv = clamp((position - viewOrigin) / viewSize, float2(0.0), float2(1.0));

    float maskAlpha = 1.0;
    float3 color = livableCompositeColor(
        layer,
        uv,
        viewOrigin,
        viewSize,
        time,
        uniforms,
        maskAlpha
    );

    return half4(half3(color * maskAlpha), half(maskAlpha));
}
