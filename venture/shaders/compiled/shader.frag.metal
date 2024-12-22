#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 10 "shader.slang"
struct pixelOutput_0
{
    float4 output_0 [[color(0)]];
};


#line 10
struct pixelInput_0
{
    float4 color_0 [[user(COLOR)]];
};


#line 40
[[fragment]] pixelOutput_0 fsMain(pixelInput_0 _S1 [[stage_in]], float4 position_0 [[position]])
{

#line 40
    pixelOutput_0 _S2 = { _S1.color_0 };

    return _S2;
}

