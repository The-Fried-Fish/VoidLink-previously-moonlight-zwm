//
//  Shaders.metal
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

constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);

vertex Vertex vs_draw(constant Vertex *vertices [[ buffer(0) ]], uint id [[ vertex_id ]])
{
    return vertices[id];
}

fragment float4 ps_draw_biplanar_8bit(Vertex v [[ stage_in ]],
                                     constant CscParams &cscParams [[ buffer(0) ]],
                                     texture2d<float> luminancePlane [[ texture(0) ]],
                                     texture2d<float> chrominancePlane [[ texture(1) ]])
{
    float3 yuv = float3(luminancePlane.sample(s, v.texCoords).r,
                        chrominancePlane.sample(s, v.texCoords).rg);
    yuv -= cscParams.offsets;

    float3 rgb;
    rgb.r = dot(yuv, cscParams.matrix[0]);
    rgb.g = dot(yuv, cscParams.matrix[1]);
    rgb.b = dot(yuv, cscParams.matrix[2]);
    return float4(rgb, 1.0f);
}

fragment float4 ps_draw_triplanar_8bit(Vertex v [[ stage_in ]],
                                      constant CscParams &cscParams [[ buffer(0) ]],
                                      texture2d<float> luminancePlane [[ texture(0) ]],
                                      texture2d<float> chrominancePlaneU [[ texture(1) ]],
                                      texture2d<float> chrominancePlaneV [[ texture(2) ]])
{
    float3 yuv = float3(luminancePlane.sample(s, v.texCoords).r,
                        chrominancePlaneU.sample(s, v.texCoords).r,
                        chrominancePlaneV.sample(s, v.texCoords).r);
    yuv -= cscParams.offsets;

    float3 rgb;
    rgb.r = dot(yuv, cscParams.matrix[0]);
    rgb.g = dot(yuv, cscParams.matrix[1]);
    rgb.b = dot(yuv, cscParams.matrix[2]);
    return float4(rgb, 1.0f);
}

fragment float4 ps_draw_biplanar_10bit(Vertex v [[ stage_in ]],
                                      constant CscParams &cscParams [[ buffer(0) ]],
                                      texture2d<float> luminancePlane [[ texture(0) ]],
                                      texture2d<float> chrominancePlane [[ texture(1) ]])
{
    // 1. Sample the textures to get the normalized float value from the GPU hardware.
    float3 yuv_hardware_normalized = float3(luminancePlane.sample(s, v.texCoords).r,
                                          chrominancePlane.sample(s, v.texCoords).rg);

    // 2. Reverse the normalization to get back to the approximate 10-bit integer value.
    // This reverses the server's (v_10bit << 6) and the hardware's (/ 65535.0) operations.
    float y_10bit = (yuv_hardware_normalized.r * 65535.0) / 64.0;
    float2 uv_10bit = (yuv_hardware_normalized.gb * 65535.0) / 64.0;

    // 3. Re-normalize the 10-bit value using the correct 1023.0 divisor that the CSC constants expect.
    float3 yuv_corrected;
    yuv_corrected.r = y_10bit / 1023.0;
    yuv_corrected.gb = uv_10bit / 1023.0;

    // 4. Use this perfectly scaled YUV value with the original CSC parameters.
    yuv_corrected -= cscParams.offsets;

    // 5. Perform the final color space conversion.
    float3 rgb;
    rgb.r = dot(yuv_corrected, cscParams.matrix[0]);
    rgb.g = dot(yuv_corrected, cscParams.matrix[1]);
    rgb.b = dot(yuv_corrected, cscParams.matrix[2]);
    return float4(rgb, 1.0f);
}

fragment float4 ps_draw_triplanar_10bit(Vertex v [[ stage_in ]],
                                       constant CscParams &cscParams [[ buffer(0) ]],
                                       texture2d<float> luminancePlane [[ texture(0) ]],
                                       texture2d<float> chrominancePlaneU [[ texture(1) ]],
                                       texture2d<float> chrominancePlaneV [[ texture(2) ]])
{
    // 1. Sample the textures to get the normalized float value from the GPU hardware.
    float y_hardware_normalized = luminancePlane.sample(s, v.texCoords).r;
    float u_hardware_normalized = chrominancePlaneU.sample(s, v.texCoords).r;
    float v_hardware_normalized = chrominancePlaneV.sample(s, v.texCoords).r;

    // 2. Reverse the normalization to get back to the approximate 10-bit integer value.
    // This reverses the server's (v_10bit << 6) and the hardware's (/ 65535.0) operations.
    float y_10bit = (y_hardware_normalized * 65535.0) / 64.0;
    float u_10bit = (u_hardware_normalized * 65535.0) / 64.0;
    float v_10bit = (v_hardware_normalized * 65535.0) / 64.0;

    // 3. Re-normalize the 10-bit value using the correct 1023.0 divisor that the CSC constants expect.
    float3 yuv_corrected;
    yuv_corrected.r = y_10bit / 1023.0;
    yuv_corrected.g = u_10bit / 1023.0;
    yuv_corrected.b = v_10bit / 1023.0;

    // 4. Use this perfectly scaled YUV value with the original CSC parameters.
    yuv_corrected -= cscParams.offsets;

    // 5. Perform the final color space conversion.
    float3 rgb;
    rgb.r = dot(yuv_corrected, cscParams.matrix[0]);
    rgb.g = dot(yuv_corrected, cscParams.matrix[1]);
    rgb.b = dot(yuv_corrected, cscParams.matrix[2]);
    return float4(rgb, 1.0f);
}
