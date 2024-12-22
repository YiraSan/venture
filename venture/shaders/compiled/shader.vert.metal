#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 1349 "diff.meta.slang"
struct _MatrixStorage_float4x4_ColMajornatural_0
{
    array<float4, int(4)> data_0;
};


#line 1349
matrix<float,int(4),int(4)>  unpackStorage_0(_MatrixStorage_float4x4_ColMajornatural_0 _S1)
{

#line 1349
    return matrix<float,int(4),int(4)> (_S1.data_0[int(0)][int(0)], _S1.data_0[int(1)][int(0)], _S1.data_0[int(2)][int(0)], _S1.data_0[int(3)][int(0)], _S1.data_0[int(0)][int(1)], _S1.data_0[int(1)][int(1)], _S1.data_0[int(2)][int(1)], _S1.data_0[int(3)][int(1)], _S1.data_0[int(0)][int(2)], _S1.data_0[int(1)][int(2)], _S1.data_0[int(2)][int(2)], _S1.data_0[int(3)][int(2)], _S1.data_0[int(0)][int(3)], _S1.data_0[int(1)][int(3)], _S1.data_0[int(2)][int(3)], _S1.data_0[int(3)][int(3)]);
}


#line 21 "shader.slang"
struct CameraData_0
{
    matrix<float,int(4),int(4)>  viewProjection_0;
};


#line 21
struct CameraData_natural_0
{
    _MatrixStorage_float4x4_ColMajornatural_0 viewProjection_0;
};


#line 21
CameraData_0 unpackStorage_1(CameraData_natural_0 _S2)
{

#line 21
    CameraData_0 _S3 = { unpackStorage_0(_S2.viewProjection_0) };

#line 21
    return _S3;
}


#line 10
struct VSOutput_0
{
    float4 position_0 [[position]];
    float4 color_0 [[user(COLOR)]];
};


#line 10
struct vertexInput_0
{
    float4 position_1 [[attribute(0)]];
    float4 color_1 [[attribute(1)]];
};


#line 10
struct EntryPointParams_natural_0
{
    CameraData_natural_0 camera_0;
};


#line 3962 "core.meta.slang"
struct InstanceData_natural_0
{
    _MatrixStorage_float4x4_ColMajornatural_0 modelMatrix_0;
};


#line 3962
struct KernelContext_0
{
    EntryPointParams_natural_0 constant* entryPointParams_0;
    InstanceData_natural_0 device* entryPointParams_instances_0;
};


#line 27 "shader.slang"
[[vertex]] VSOutput_0 vsMain(vertexInput_0 _S4 [[stage_in]], uint instanceID_0 [[instance_id]], EntryPointParams_natural_0 constant* entryPointParams_1 [[buffer(0)]], InstanceData_natural_0 device* entryPointParams_instances_1 [[buffer(1)]])
{

    KernelContext_0 kernelContext_0;

#line 30
    (&kernelContext_0)->entryPointParams_0 = entryPointParams_1;

#line 30
    (&kernelContext_0)->entryPointParams_instances_0 = entryPointParams_instances_1;

    thread VSOutput_0 output_0;
    (&output_0)->position_0 = ((((((_S4.position_1) * (unpackStorage_0((entryPointParams_instances_1+instanceID_0)->modelMatrix_0))))) * (unpackStorage_1((&kernelContext_0)->entryPointParams_0->camera_0).viewProjection_0)));
    (&output_0)->color_0 = _S4.color_1;
    return output_0;
}

