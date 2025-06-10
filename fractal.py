import moderngl
import pygame
from pygame.locals import OPENGL, DOUBLEBUF
import numpy as np
import os

# 初始化 Pygame OpenGL 窗口
pygame.init()
width, height = 600, 600
pygame.display.set_mode((width, height), OPENGL | DOUBLEBUF)

ctx = moderngl.create_context()

# 获取当前脚本所在目录
script_dir = os.path.dirname(os.path.abspath(__file__))

# 加载 shader 文件
def load_shader(shader_type, filename):
    with open(filename, 'r') as f:
        return f.read()

vertex_code = load_shader("vertex", os.path.join(script_dir, "vertex_shader.glsl"))
update_code = load_shader("fragment", os.path.join(script_dir, "fragment_shader_update.glsl"))
render_code = load_shader("fragment", os.path.join(script_dir, "fragment_shader_render.glsl"))

# 创建 program
prog_update = ctx.program(vertex_shader=vertex_code, fragment_shader=update_code)
prog_render = ctx.program(vertex_shader=vertex_code, fragment_shader=render_code)

# 全屏四边形顶点数据
quad_vertex_data = np.array([
    -1.0, -1.0,
     1.0, -1.0,
    -1.0,  1.0,
     1.0,  1.0,
], dtype=np.float32)

vbo = ctx.buffer(quad_vertex_data.tobytes())

vao_update = ctx.vertex_array(prog_update, [(vbo, '2f', 'in_vert')])
vao_render = ctx.vertex_array(prog_render, [(vbo, '2f', 'in_vert')])

# 创建两个 RGBA16F 纹理（每个通道为 2 字节）
textures = [
    ctx.texture((width, height), 4, dtype='f4'),
    ctx.texture((width, height), 4, dtype='f4')
]
for tex in textures:
    tex.repeat_x = False
    tex.repeat_y = False
    tex.filter = (moderngl.LINEAR, moderngl.LINEAR)

# 创建帧缓冲对象
fbo = [ctx.framebuffer(color_attachments=[textures[0]]),
       ctx.framebuffer(color_attachments=[textures[1]])]

# 设置初始状态：每个像素为 (x, y, vx, vy)
initial_data = np.zeros((height, width, 4), dtype=np.float32)

for y in range(height):
    for x in range(width):
        nx = (float(x) / float(width)) * 2 - 1  # x ∈ [-1, 1]
        ny = (float(y) / float(height)) * 2 - 1 # y ∈ [-1, 1]
        initial_data[y, x] = [nx, ny, 0.0, 1.0]

initial_data = np.ascontiguousarray(initial_data)
textures[0].write(initial_data)

raw_data = textures[0].read()
arr = np.frombuffer(raw_data, dtype=np.float32).reshape(height, width, 4)
print("Initial state at (0,0):", arr[0, 0])

current_buffer = 0
running = True
frame = 0

while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False

    # 更新状态纹理
    fbo[current_buffer].use()
    ctx.clear()
    textures[1 - current_buffer].use(location=0)
    prog_update['stateTex'] = 0
    prog_update['dt'] = 0.00001
    prog_update['if_frame0'] = frame
    vao_update.render(moderngl.TRIANGLE_STRIP)

    # 切换 buffer
    current_buffer = 1 - current_buffer

    # 渲染到屏幕
    ctx.screen.use()
    textures[current_buffer].use(location=0)
    prog_render['stateTex'] = 0
    vao_render.render(moderngl.TRIANGLE_STRIP)

    pygame.display.flip()

    # 调试输出：每隔一定帧数读取左上角像素的 state
    if frame % 1200 == 0:
        # 读取当前纹理数据
        raw_data = textures[current_buffer].read()
        # 转换为 float16（与纹理 dtype 一致）
        state_array = np.frombuffer(raw_data, dtype=np.float32).reshape(height, width, 4)

        # 获取左上角像素的 state 值（注意有些纹理是倒置的）
        x = 300
        y = 300
        # 如果读取不到有效值，可尝试：y = height - 1 - y
        state = state_array[y, x]

        print(f"Frame {frame}: Pixel ({x}, {y}) -> x={state[0]:.4f}, y={state[1]:.4f}, vx={state[2]:.4f}, vy={state[3]:.4f}")

    frame += 1

pygame.quit()