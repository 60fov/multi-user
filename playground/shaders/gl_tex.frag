#version 460 core

out vec4 out_frag;

in vec2 uv;

uniform sampler2D tex1;

void main() {
    out_frag = texture(tex1, uv);
}