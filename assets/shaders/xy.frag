#version 460 core

out vec4 fragColor;
in vec4 fCol;

void main() {
    fragColor = fCol;
}