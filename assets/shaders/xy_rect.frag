#version 460 core

out vec4 out_frag;

in vec4 f_col;

void main() {
    out_frag = f_col;
}