#version 330
in vec2 uv;
uniform sampler2D stateTex;
uniform float dt;
uniform int if_frame0;
out vec4 fragColor;

// 常量定义
const float m = 0.01;       // 质量 [kg]
const float g = 9.8;        // 重力加速度 [m/s^2]
const float L = 0.2;        // 约束长度 [m]
const float h = 0.02;       // 自由下垂高度 [m]
const float eta = 0.001;    // 阻尼系数
const float m0 = 0.5;       // 磁矩大小 [A·m^2]
const float mu0 = 4.0 * 3.141592653589793 * 1e-7; // 真空磁导率

// 磁铁数量和位置信息
const int N = 3;
vec2 mag_pos[N] = vec2[](vec2(-0.03, 0.0), vec2(0.03, 0.0), vec2(5.0, 0.0));
float mag_moments[N] = float[](1.0, 1.0, 1.0); // 磁矩方向

// ================== 磁势能函数 ==================
float magnetic_potential(vec2 pos, vec2 xi, float mi) {
    float H = sqrt(L*L - pos.x*pos.x - pos.y*pos.y);
    float z = L + h - H;
    vec2 r = pos - xi;
    float Ri = length(vec3(r, z));
    return (mu0 * mi * m0) / (4.0 * 3.141592653589793 * L * pow(Ri, 3)) * H;
}

// ================== 磁场力（梯度负值）==================
vec2 magnetic_force(vec2 pos, vec2 xi, float mi) {
    float eps = 1e-6;

    float Eb_xp = magnetic_potential(pos + vec2(eps, 0.0), xi, mi);
    float Eb_xm = magnetic_potential(pos - vec2(eps, 0.0), xi, mi);
    float Fx_B = -(Eb_xp - Eb_xm) / (2.0 * eps);

    float Eb_yp = magnetic_potential(pos + vec2(0.0, eps), xi, mi);
    float Eb_ym = magnetic_potential(pos - vec2(0.0, eps), xi, mi);
    float Fy_B = -(Eb_yp - Eb_ym) / (2.0 * eps);

    return vec2(Fx_B, Fy_B);
}

// ================== 总磁场合力 ==================
vec2 total_magnetic_force(vec2 pos) {
    vec2 F_total = vec2(0.0);
    for (int k = 0; k < N; k++) {
        vec2 xi = mag_pos[k];
        float mi = mag_moments[k];
        vec2 F = magnetic_force(pos, xi, mi);
        F_total -= F;
    }
    return F_total;
}

// ================== 主函数 ==================
void main() {
    vec4 state = texture(stateTex, uv);  // x, y, vx, vy
    float x = state.x;
    float y = state.y;
    float vx = state.z;
    float vy = state.w;

    if (if_frame0 == 0) {
        x = 0.1 * (0.5 - uv.x);
        y = 0.1 * (0.5 - uv.y);
        vx = 0.0;
        vy = 0.0;
    }

    vec2 pos = vec2(x, y);
    vec2 vel = vec2(vx, vy);
    float H = sqrt(L*L - x*x - y*y);
    float H2 = H * H;
    float H4 = H2 * H2;
    float xy_term = x * vx + y * vy;

    // 重力项
    vec2 F_gravity = -m * g * vec2(x, y) / H;

    float Fx_gravity = -m * g * x / H;

    float Fx_nonlinear1 = -(pow(x, 3)/H4 + x/H2) * m * vx * vx;
    float Fx_nonlinear2 = -(2.0 * m * x * x * y * vx * vy) / H4;
    float Fx_nonlinear3 = -(m * x * y * y * vy * vy) / H4;
    float Fx_nonlinear4 = (m * x * vy * vy) / H2;
    float Fx_nonlinear5 = (2.0 * m * x * y * vy * xy_term) / H4;
    float Fx_nonlinear6 = (2.0 * x * vx / H2 + 2.0 * x * x * xy_term / H4) * m * vx;

    float Fx_nonlinear_total = 
        Fx_nonlinear1 +
        Fx_nonlinear2 +
        Fx_nonlinear3 +
        Fx_nonlinear4 +
        Fx_nonlinear5 +
        Fx_nonlinear6;

    // 阻尼项
    float Fx_damping = -(1.0 + x*x / H2) * vx * eta;

    // 磁场力
    vec2 F_magnetic = total_magnetic_force(pos);
    float Fx_magnetic = F_magnetic.x;

    // 总力 Fx
    float Fx = Fx_gravity + Fx_nonlinear_total + Fx_damping ;
    F_magnetic.x =  Fx_magnetic;

    // ================== Fy 分量 ==================
    float Fy_gravity = -m * g * y / H;

    float Fy_nonlinear1 = -(pow(y, 3)/H4 + y/H2) * m * vy * vy;
    float Fy_nonlinear2 = -(2.0 * m * x * y * y * vx * vy) / H4;
    float Fy_nonlinear3 = -(m * x * x * y * vx * vx) / H4;
    float Fy_nonlinear4 = (m * y * vx * vx) / H2;
    float Fy_nonlinear5 = (2.0 * m * x * y * vx * xy_term) / H4;
    float Fy_nonlinear6 = (2.0 * y * vy / H2 + 2.0 * y * y * xy_term / H4) * m * vy;

    float Fy_nonlinear_total = 
        Fy_nonlinear1 +
        Fy_nonlinear2 +
        Fy_nonlinear3 +
        Fy_nonlinear4 +
        Fy_nonlinear5 +
        Fy_nonlinear6;

    float Fy_damping = -(1.0 + y*y / H2) * vy * eta;
    float Fy_magnetic = F_magnetic.y;

    // 总力 Fy
    float Fy = Fy_gravity + Fy_nonlinear_total + Fy_damping ;
    F_magnetic.y =  Fy_magnetic;

    vec2 F_total = vec2(Fx, Fy) + F_magnetic;

    float a = 1.0 + (x * x) / H2;
    float b = (x * y) / H2;
    float d = 1.0 + (y * y) / H2;

    // 行列式 det(M)
    float det = a * d - b * b;

    // 逆矩阵（不乘 m，因为力已经包含 m）
    mat2 M_inv = mat2(
        d, -b,
        -b,  a
    ) / det;

    // 半隐式欧拉更新：先更新速度，再更新位置
    vel += M_inv * F_total / m * dt;
    pos += vel * dt;

    // 输出新状态
    fragColor = vec4(pos.x, pos.y, vel.x, vel.y);
}