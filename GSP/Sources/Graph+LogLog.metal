//
//  Graph+LogLog.metal
//  MUTE
//
//  Created by Kota on 10/31/25.
//
#include <metal_stdlib>
using namespace metal;
struct VertexOut {
    float4 position [[ position ]];
};
vertex VertexOut loglogv(constant float2 const & xs [[ buffer(0) ]],
                         constant float2 const & ys [[ buffer(1) ]],
                         device float const * const x [[ buffer(2) ]],
                         device float const * const y [[ buffer(3) ]],
                         uint const n [[ vertex_id ]]) {
    return {
        .position=float4(fma(log10(x[n]), xs.x, xs.y),
                         fma(log10(y[n]), ys.x, ys.y), 0, 1)
    };
}
fragment half4 loglogf(VertexOut vbo [[ stage_in ]],
                       constant float4 const & c [[ buffer(0) ]]) {
    return half4(c);
}
