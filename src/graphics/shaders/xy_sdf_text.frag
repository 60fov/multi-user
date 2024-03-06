#version 460 core

out vec4 out_frag;

in vec2 f_uv;
in vec4 f_col;
in flat uint character;

layout (binding = 0) uniform sampler2DArray font_tex;

float layer(uint capacity, uint layer) {
	return max(0, min(float(capacity - 1), floor(float(layer) + 0.5)));
}

void main() {
    vec3 coord = vec3(f_uv, layer(256, character));
    vec4 samp = texture(font_tex, coord);
    if (samp.r < 0.5) discard;
    out_frag = samp * f_col;
}