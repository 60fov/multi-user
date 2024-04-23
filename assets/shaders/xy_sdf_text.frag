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
    float samp = texture(font_tex, coord).r;

    float scale = 1.0 / fwidth(samp);
    float signedDistance = (samp - 0.5) * scale;
    float alpha = clamp(signedDistance + 0.5, 0.0, 1.0);
    if (samp < 0.4) discard;
    out_frag = vec4(f_col.xyz, alpha);
}