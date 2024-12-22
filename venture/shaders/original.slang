// Shader for vertex and fragment processing in Slang Shading Language

// Input structure for vertex shader
struct VSInput {
    float4 position : ATTRIB0; // Attribute 0 for position
    float4 color    : ATTRIB1; // Attribute 1 for color
};

// Output structure for vertex shader
struct VSOutput {
    float4 position : SV_Position; // System-defined position semantic
    float4 color    : COLOR0;      // Color output for interpolation
};

// Instance data structure
struct InstanceData {
    float4x4 modelMatrix; // Per-instance model matrix
};

// Camera uniform buffer structure
struct CameraData {
    float4x4 viewProjection; // View-projection matrix
};

// Vertex shader
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

// Fragment shader
[shader("fragment")]
float4 fsMain(VSOutput input) : SV_Target 
{
    return input.color; // Output interpolated color
}
