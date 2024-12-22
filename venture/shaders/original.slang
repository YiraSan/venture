
struct VSInput {
    float4 position : ATTRIB0;
    float4 color    : ATTRIB1;
};

struct VSOutput {
    float4 position : SV_Position;
    float4 color    : COLOR0;
};

struct InstanceData {
    float4x4 modelMatrix;
};

struct CameraData {
    float4x4 viewProjection;
};

[shader("vertex")]
VSOutput vsMain(VSInput input, 
                uniform CameraData camera : register(t0), 
                StructuredBuffer<InstanceData> instances : register(t1),
                uint instanceID : SV_InstanceID) 
{
    VSOutput output;
    output.position = mul(camera.viewProjection, mul(instances[instanceID].modelMatrix, input.position));
    output.color = input.color;
    return output;
}

[shader("fragment")]
float4 fsMain(VSOutput input) : SV_Target 
{
    return input.color;
}
