#version 460 core

layout (location = 0) in vec2 aPos;
// TODO update vertices to include uvs
layout (location = 1) in vec2 aUv;

// TODO combine pos and size into vec4
// layout (location = 2) in vec4 i_dim;
layout (location = 2) in vec2 iPos;
layout (location = 3) in vec2 iSize;
// TODO create vec4 from uv transform from char to atlas space
// layout (location = 4) in vec4 i_atlas;
// TODO add transparency to color
layout (location = 5) in vec3 iColor;

out vec4 fCol;
out vec2 vUv;
out vec2 tUv;

void main()
{
    float sx = 2 * iSize.x / 800;
    float sy = 2 * iSize.y / 600;
    float tx = 2 * iPos.x / 800 - 1;
    float ty = 2 * iPos.y / 600 - 1;
    
    mat3 mat = mat3(
        sx, 0, tx,
        0, sy, ty,
        0, 0, 1
    );


    vec3 pos = vec3(aPos, 1.0) * mat;
    // vec3 uv = vec3(aUv, 1.0) * tex_mat;

    gl_Position = vec4(pos.xy, 0.0, 1.0);
    fCol = vec4(iColor, 1.0);
}  