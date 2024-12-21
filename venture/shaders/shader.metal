// language: metal1.0
#include <metal_stdlib>
#include <simd/simd.h>

using metal::uint;

struct Payload {
    metal::float4 position;
    metal::float4 color;
};

struct vs_mainInput {
    metal::float4 position [[attribute(0)]];
    metal::float4 color [[attribute(1)]];
};
struct vs_mainOutput {
    metal::float4 position [[position]];
    metal::float4 color [[user(loc0), center_perspective]];
};
vertex vs_mainOutput vs_main(
  vs_mainInput varyings [[stage_in]]
) {
    const auto position = varyings.position;
    const auto color = varyings.color;
    Payload output = {};
    output.position = position;
    output.color = color;
    Payload _e5 = output;
    const auto _tmp = _e5;
    return vs_mainOutput { _tmp.position, _tmp.color };
}


struct fs_mainInput {
    metal::float4 color [[user(loc0), center_perspective]];
};
struct fs_mainOutput {
    metal::float4 member_1 [[color(0)]];
};
fragment fs_mainOutput fs_main(
  fs_mainInput varyings_1 [[stage_in]]
, metal::float4 position_1 [[position]]
) {
    const Payload payload = { position_1, varyings_1.color };
    return fs_mainOutput { payload.color };
}
