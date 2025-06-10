#version 330
in vec2 uv;
uniform sampler2D stateTex;
out vec4 fragColor;

void main() {
    vec4 state = texture(stateTex, uv);  // x, y, vx, vy
    float vx = state.z;
    float vy = state.w;

    // 颜色基于速度大小
    float speed = sqrt(vx*vx + vy*vy);
    if (speed > 1) speed = 1;
    //fragColor = vec4(speed, speed, 1.0, 1.0);
    int lx = int(state.x * 100 + 100);
    int ly = int(state.y * 100 + 100);
    float color = 0;
    if ((lx + ly)%2 == 0 )color = 1;
    //fragColor = vec4(color,color,color + (0.5-color)*30*speed,1);
    fragColor = vec4(state.x*25/2+0.5,state.y*25/2+0.5,state.y*25/2+0.5,1);
}