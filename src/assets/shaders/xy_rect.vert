#version 460 core

struct Instance {
    vec4 pos;
    vec2 size;
    vec4 color;
};

layout (location = 0) in vec2 v_xy;

// SSBO containing the instanced model matrices
layout(binding = 0, std430) readonly buffer ssbo_info {
    vec2 screen;
    vec2 font;
};

layout(binding = 1, std430) readonly buffer ssbo_inst {
    Instance inst_arr[];
};

out vec4 f_col;

void main() {
    Instance inst = inst_arr[gl_InstanceID];
    float sx = 2 * inst.size.x / screen.x; // screen width
    float sy = 2 * inst.size.y / screen.y; // screen height
    float tx = 2 * inst.pos.x / screen.x - 1;
    float ty = 2 * inst.pos.y / screen.y - 1;

    mat3 mat = mat3(
        sx, 0, tx,
        0, sy, ty,
        0, 0, 1
    );

    vec3 pos = vec3(v_xy, 1.0) * mat;

    gl_Position = vec4(pos.xy, inst.pos.z, 1.0);
    f_col = inst.color;
}