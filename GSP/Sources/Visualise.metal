//
//  Visualise.metal
//  MUTE
//
//  Created by Kota on 1/6/26.
//
#include<metal_stdlib>
using namespace metal;
struct StageIn {
    float4 position [[ position ]];
};
[[fragment]]
half4 white(StageIn stage_in [[ stage_in ]]) {
    return {1, 1, 1, 1};
}
