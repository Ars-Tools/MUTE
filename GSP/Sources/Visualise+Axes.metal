//
//  Visualise+Axes.metal
//  MUTE
//
//  Created by Kota on 1/5/26.
//
#include<metal_stdlib>
using namespace metal;
int constant MAX_PRIMITIVES = 64;
int constant MAX_VERTICES = 2 * MAX_PRIMITIVES;
// metal::mesh<V, P, NV, NP, t>
//  V  - vertex type (output struct)
//  P  - primitive type (output struct)
//  NV - max number of vertices
//  NP - max number of primitives
//  t  - topology
struct StageIn {
    float4 position [[ position ]];
};
[[mesh]]
void xaxis(mesh<StageIn, void, MAX_VERTICES, MAX_PRIMITIVES, topology::line> out,
           float constant * const buffer [[ buffer(0) ]],
           uint constant const & length [[ buffer(1) ]],
           uint const lid [[ thread_position_in_threadgroup ]],
           uint const gid [[ thread_position_in_grid ]]) {
    int const quotient = gid >> 1;
    int const remainder = gid & 1;
    switch ( lid ) {
        case 0:
            out.set_primitive_count(min(MAX_PRIMITIVES, int(length) - quotient));
        default:
            out.set_vertex(lid, { { buffer[quotient], float(2 * remainder - 1), 0.0, 1.0 } });
            out.set_index(lid, lid);
    }
}
[[mesh]]
void yaxis(mesh<StageIn, void, MAX_VERTICES, MAX_PRIMITIVES, topology::line> out,
           float constant * const buffer [[ buffer(0) ]],
           uint constant const & length [[ buffer(1) ]],
           uint const lid [[ thread_position_in_threadgroup ]],
           uint const gid [[ thread_position_in_grid ]]) {
    int const quotient = gid >> 1;
    int const remainder = gid & 1;
    switch ( lid ) {
        case 0:
            out.set_primitive_count(min(MAX_PRIMITIVES, int(length) - int(quotient)));
        default:
            out.set_vertex(lid, { { float(2 * remainder - 1), buffer[quotient], 0.0, 1.0 } });
            out.set_index(lid, lid);
    }
}
[[mesh]]
void label() {
    
}
