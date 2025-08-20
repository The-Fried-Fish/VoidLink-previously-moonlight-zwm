//
//  Shaders-Linear.metal
//
//  Created by Andy Grundman.
//  Ported to VoidLink by Acaki.
//  Copyright (c) 2025 Moonlight Stream. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct Vertex
{
    float4 position [[ position ]];
    float2 texCoords;
};

struct CscParams
{
    float3 matrix[3];
    float3 offsets;
};

// PQ (SMPTE ST 2084) constants for inverse EOTF
constant float PQ_C1 = 0.8359375;          // 3424/4096
constant float PQ_C2 = 18.8515625;         // 2413/128
constant float PQ_C3 = 18.6875;            // 299/16
constant float PQ_M = 78.84375;            // 2523/32
constant float PQ_N = 0.1593017578125;     // 1305/8192

// BT.2020 to Rec.709/sRGB color space conversion matrix
constant float3x3 bt2020_to_rec709 = float3x3(
    float3( 1.7166511, -0.3556708, -0.2533663),
    float3(-0.6666844,  1.6164812,  0.0157685),
    float3( 0.0176399, -0.0427706,  0.9421031)
);

constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);


float3 scaleEDR(float3 rgb, float maxInput, float maxOutput) {
    if (maxInput <= maxOutput) {
        return rgb;
    }
    float a = maxOutput / (maxInput * maxInput);
    float b = 1.0f / maxOutput;
    float colorMax = max(rgb.r, max(rgb.g, rgb.b));
    return rgb * (1.0f + a * colorMax) / (1.0f + b * colorMax);
}

// Convert from PQ curve to linear light
float pq_to_linear(float pq) {
    if (pq <= 0.0) return 0.0;

    float pq_pow_inv_m = pow(pq, 1.0 / PQ_M);
    float numerator = max(pq_pow_inv_m - PQ_C1, 0.0);
    float denominator = PQ_C2 - PQ_C3 * pq_pow_inv_m;

    if (denominator <= 0.0) return 0.0;

    return 10000.0f * pow(numerator / denominator, 1.0 / PQ_N);
}

// Apply PQ inverse EOTF to RGB components
float3 pq_to_linear_rgb(float3 pq_rgb) {
    return float3(
        pq_to_linear(pq_rgb.r),
        pq_to_linear(pq_rgb.g),
        pq_to_linear(pq_rgb.b)
    );
}

fragment float4 yuvToLinear(Vertex v [[ stage_in ]],
                            constant CscParams &cscParams [[ buffer(0) ]],
                            constant float &edrHeadroom [[ buffer(1) ]],
                            texture2d<float> luminancePlane [[ texture(0) ]],
                            texture2d<float> chrominancePlane [[ texture(1) ]])
{
    // 1. Sample the textures to get the raw float value from the GPU hardware.
    float3 yuv_hardware_normalized = float3(luminancePlane.sample(s, v.texCoords).r,
                                          chrominancePlane.sample(s, v.texCoords).rg);

    // 2. Reverse the hardware normalization to get back to the approximate 10-bit integer value.
    // This reverses the server's (v_10bit << 6) and the hardware's (/ 65535.0) operations.
    float y_10bit = (yuv_hardware_normalized.r * 65535.0) / 64.0;
    float2 uv_10bit = (yuv_hardware_normalized.gb * 65535.0) / 64.0;

    // 3. Re-normalize the 10-bit value using the correct 1023.0 divisor that the CSC constants expect.
    float3 yuv_corrected;
    yuv_corrected.r = y_10bit / 1023.0;
    yuv_corrected.gb = uv_10bit / 1023.0;

    // 4. Use this perfectly scaled YUV value for the color conversion.
    yuv_corrected -= cscParams.offsets;

    float3 rgb;
    rgb.r = dot(yuv_corrected, cscParams.matrix[0]);
    rgb.g = dot(yuv_corrected, cscParams.matrix[1]);
    rgb.b = dot(yuv_corrected, cscParams.matrix[2]);

    // Clamp RGB to valid range [0, 1]
    rgb = clamp(rgb, 0.0, 1.0);

    // Apply PQ inverse EOTF to convert from gamma-encoded to linear light
    // This converts from 0-1 PQ range to 0-10000 nits linear
    float3 linear_rgb = pq_to_linear_rgb(rgb);

    // Scale from PQ (0-10000) to EDR (1.0 = 100 nits SDR white)
    const float referenceWhite = 100.0f; // must match opticalOutputScale in EDRMetadata
    const float peakWhite = 10000.0f;
    linear_rgb = linear_rgb / referenceWhite;

    // This will apply linear tone-mapping to scale all values to not exceed peak, not really what we want
    //linear_rgb = scaleEDR(linear_rgb / referenceWhite, peakWhite / referenceWhite, edrHeadroom);

    // TODO: support tonemapping to Rec.709 for non-HDR viewers
    //linear_rgb = bt2020_to_rec709 * linear_rgb;

    return float4(linear_rgb, 1.0f);
}
