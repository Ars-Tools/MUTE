//
//  GrayScott.metal
//  MUTE
//
//  Created by Kota on 12/2/25.
//
#include<metal_stdlib>
using namespace metal;
constant float f [[ function_constant(0) ]];
constant float k [[ function_constant(1) ]];
constant float Du [[ function_constant(2) ]];
constant float Dv [[ function_constant(3) ]];
constant float dx [[ function_constant(4) ]];
constant float dt [[ function_constant(5) ]];
struct VertexOut {
    float4 position [[ position ]];
    float2 coord;
};
kernel void gscs(texture2d_array<float, access::read_write> const field [[ texture(0) ]],
                 texture2d<uint, access::read_write> const noise [[ texture(1) ]],
                 uint2 const i [[ thread_position_in_grid ]],
                 uint2 const p [[ threads_per_grid ]]) {
    
    uint s = noise.read(i).x;
    s ^= s << 13;
    s ^= s >> 17;
    s ^= s << 5;
    noise.write(s, i);
    float const u0 = (( s         ) % 65536) / 65536.0;
    float const u1 = (( s / 65536 ) % 65536) / 65536.0;
    
    float const u = field.read(i, 0).x;
    float const v = field.read(i, 1).x;
    float const lu = (field.read(i + uint2(0, 1), 0).x +
                      field.read(i - uint2(0, 1), 0).x +
                      field.read(i + uint2(1, 0), 0).x +
                      field.read(i - uint2(1, 0), 0).x -
                      4 * u) / dx / dx;
    float const lv = (field.read(i + uint2(0, 1), 1).x +
                      field.read(i - uint2(0, 1), 1).x +
                      field.read(i + uint2(1, 0), 1).x +
                      field.read(i - uint2(1, 0), 1).x -
                      4 * v) / dx / dx;
    float const dudt = Du * lu - u * v * v + f * ( 1 - u );
    float const dvdt = Dv * lv + u * v * v - ( f + k ) * v;
    field.write(u + dt * dudt + fma(u0, 0.01, -0.005), i, 0);
    field.write(v + dt * dvdt + fma(u1, 0.01, -0.005), i, 1);
}
vertex VertexOut gsvs(device float2 const * const x [[ buffer(0) ]],
                      device uint const & r [[ buffer(1) ]],
                      uint const n [[ vertex_id ]]) {
    float const c = cospi(r * 0.01);
    float const s = sinpi(r * 0.01);
    
    return {
        .position=float4(float2x2(c, s, -s, c) * fma(x[n], 2, -1), 0, 1),
        .coord=x[n]
    };
}
fragment float4 gsfs(VertexOut const vbo [[ stage_in ]],
                    texture2d_array<float, access::sample> const field [[ texture(0) ]]) {
//    return half4(half2(vbo.coord), 1, 1);
    return float4(field.sample(sampler(address::clamp_to_zero, filter::nearest), vbo.coord, 0).xxx, 1);
}
