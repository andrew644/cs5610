const std = @import("std");
const math = @import("std").math;

const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});
const gl = @cImport({
    @cInclude("GL/gl.h");
});
const glad = @cImport({
    @cInclude("include/glad/glad.h");
});
const ass = @cImport({
    @cInclude("assimp/cimport.h");
    @cInclude("assimp/scene.h");
    @cInclude("assimp/postprocess.h");
});

const vertex_shader_src =
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos;
    \\
    \\uniform mat4 uProjection;
    \\uniform mat4 uView;
    \\uniform mat4 uModel;
    \\
    \\void main() {
    \\    gl_Position = uProjection * uView * uModel * vec4(aPos, 1.0);
    \\    gl_PointSize = 10.0;
    \\}
;

const fragment_shader_src =
    \\#version 330 core
    \\out vec4 FragColor;
    \\void main() {
    \\    FragColor = vec4(1.0, 1.0, 1.0, 1.0);
    \\}
;

var right_mouse_down = false;
var left_mouse_down = false;
var last_mouse_x: f64 = 0.0;
var last_mouse_y: f64 = 0.0;
var zoom_distance: f32 = 24;
const zoom_speed = 0.01;
var yaw: f32 = 0;
var pitch: f32 = -1;
var window_width: i32 = 1024;
var window_height: i32 = 768;

pub fn project2() !void {
    const fov_deg = 90.0;
    const near_fov = 1;
    const far_fov = 100.0;
    const filename = "assets/teapot.obj";
    const scene = ass.aiImportFile(filename, ass.aiProcessPreset_TargetRealtime_MaxQuality);
    if (scene == null) {
        std.debug.print("Failed to load teapot: {s}\n", .{ass.aiGetErrorString()});
        return;
    }
    defer ass.aiReleaseImport(scene);
    const mesh = scene.*.mMeshes[0];
    const num_verticies = mesh.*.mNumVertices;

    const float_vertices = try std.heap.c_allocator.alloc(f32, num_verticies * 3);
    defer std.heap.c_allocator.free(float_vertices);

    for (mesh.*.mVertices[0..num_verticies], 0..) |v, i| {
        float_vertices[i * 3 + 0] = v.x;
        float_vertices[i * 3 + 1] = v.y;
        float_vertices[i * 3 + 2] = v.z;
    }

    var model_mat: [16]f32 = .{
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
    };
    const ar: f32 = @as(f32, @floatFromInt(window_width)) / @as(f32, @floatFromInt(window_height));
    const z_range = near_fov - far_fov;
    const tan_half_fov: f32 = @tan((math.pi / 180.0) * fov_deg / 2.0);
    var project_mat: [16]f32 = .{
        1 / (ar * tan_half_fov), 0.0,              0.0,                                  0.0,
        0.0,                     1 / tan_half_fov, 0.0,                                  0.0,
        0.0,                     0.0,              (far_fov + near_fov) / z_range,       -1.0,
        0.0,                     0.0,              (2.0 * far_fov * near_fov) / z_range, 0.0,
    };

    if (glfw.glfwInit() == glfw.GLFW_FALSE) {
        std.debug.print("GLFW failed to load.\n", .{});
        return;
    }

    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);

    const window = glfw.glfwCreateWindow(window_width, window_height, "CS5610", null, null);
    if (window == null) {
        std.debug.print("Window failed to create.\n", .{});
        return error.WindowCreationFailed;
    }
    _ = glfw.glfwSetFramebufferSizeCallback(window, framebufferSizeCallback);
    _ = glfw.glfwSetMouseButtonCallback(window, mouseButtonCallback);
    _ = glfw.glfwSetCursorPosCallback(window, cursorPosCallback);

    glfw.glfwMakeContextCurrent(window);

    defer glfw.glfwTerminate();
    defer glfw.glfwDestroyWindow(window);

    if (glad.gladLoadGLLoader(@ptrCast(&glfw.glfwGetProcAddress)) == 0) {
        std.debug.print("GLAD failed.\n", .{});
        return error.GLADInitFailed;
    }
    var vao: gl.GLuint = undefined;
    if (glad.glad_glGenVertexArrays) |f| f(1, &vao);
    glad.glBindVertexArray(vao);

    var vbo: gl.GLuint = undefined;
    glad.glGenBuffers(1, &vbo);
    glad.glBindBuffer(gl.GL_ARRAY_BUFFER, vbo);
    glad.glBufferData(gl.GL_ARRAY_BUFFER, num_verticies * 3 * @sizeOf(f32), float_vertices.ptr, gl.GL_STATIC_DRAW);

    glad.glVertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, 3 * @sizeOf(f32), null);
    glad.glEnableVertexAttribArray(0);

    //Shader
    const vertex_shader = try createShader(gl.GL_VERTEX_SHADER, vertex_shader_src);
    const fragment_shader = try createShader(gl.GL_FRAGMENT_SHADER, fragment_shader_src);
    const shader_program = glad.glCreateProgram();
    glad.glAttachShader(shader_program, vertex_shader);
    glad.glAttachShader(shader_program, fragment_shader);
    glad.glLinkProgram(shader_program);
    glad.glDeleteShader(vertex_shader);
    glad.glDeleteShader(fragment_shader);
    //Get input for shader
    const project_loc = glad.glGetUniformLocation(shader_program, "uProjection");
    const view_loc = glad.glGetUniformLocation(shader_program, "uView");
    const model_loc = glad.glGetUniformLocation(shader_program, "uModel");

    while (glfw.glfwWindowShouldClose(window) != glfw.GLFW_TRUE) {
        if (glfw.glfwGetKey(window, glfw.GLFW_KEY_ESCAPE) == glfw.GLFW_PRESS) {
            glfw.glfwSetWindowShouldClose(window, glfw.GLFW_TRUE);
        }

        const cy = @cos(-yaw);
        const sy = @sin(-yaw);
        const cp = @cos(-pitch);
        const sp = @sin(-pitch);
        var view_mat: [16]f32 = .{
            cy,  sp * sy, cp * sy,        0.0,
            0.0, cp,      -sp,            0.0,
            -sy, sp * cy, cp * cy,        0.0,
            0.0, 0.0,     -zoom_distance, 1.0,
        };

        gl.glClearColor(0.1, 0.1, 0.1, 1.0);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);

        glad.glUseProgram(shader_program);

        //Set shader values
        glad.glUniformMatrix4fv(view_loc, 1, gl.GL_FALSE, @ptrCast(&view_mat));
        glad.glUniformMatrix4fv(model_loc, 1, gl.GL_FALSE, @ptrCast(&model_mat));
        glad.glUniformMatrix4fv(project_loc, 1, gl.GL_FALSE, @ptrCast(&project_mat));

        glad.glBindVertexArray(vao);
        glad.glDrawArrays(gl.GL_POINTS, 0, @intCast(num_verticies));

        glfw.glfwSwapBuffers(window);
        glfw.glfwPollEvents();
    }
}

pub fn createShader(kind: gl.GLenum, src: []const u8) !gl.GLuint {
    const id = glad.glCreateShader(kind);
    const srcs = [_][*c]const u8{src.ptr};
    glad.glShaderSource(id, 1, &srcs[0], null);
    glad.glCompileShader(id);

    var success: gl.GLint = 0;
    glad.glGetShaderiv(id, glad.GL_COMPILE_STATUS, &success);
    if (success == 0) return error.ShaderCompileError;

    return id;
}

pub fn framebufferSizeCallback(_: ?*glfw.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    window_height = height;
    window_width = width;
    glfw.glViewport(0, 0, width, height);
}

fn mouseButtonCallback(window: ?*glfw.struct_GLFWwindow, button: c_int, action: c_int, _: c_int) callconv(.C) void {
    if (button == glfw.GLFW_MOUSE_BUTTON_RIGHT) {
        if (action == glfw.GLFW_PRESS) {
            right_mouse_down = true;
            _ = glfw.glfwGetCursorPos(window, &last_mouse_x, &last_mouse_y);
        } else if (action == glfw.GLFW_RELEASE) {
            right_mouse_down = false;
        }
    }
    if (button == glfw.GLFW_MOUSE_BUTTON_LEFT) {
        if (action == glfw.GLFW_PRESS) {
            left_mouse_down = true;
            _ = glfw.glfwGetCursorPos(window, &last_mouse_x, &last_mouse_y);
        } else if (action == glfw.GLFW_RELEASE) {
            left_mouse_down = false;
        }
    }
}

fn cursorPosCallback(_: ?*glfw.struct_GLFWwindow, xpos: f64, ypos: f64) callconv(.C) void {
    const dx = xpos - last_mouse_x;
    const dy = ypos - last_mouse_y;
    if (right_mouse_down) {
        zoom_distance += @floatCast(dy * zoom_speed); // positive dy zooms out
        //zoom_distance = @max(1.0, @min(zoom_distance, 20.0));

        last_mouse_x = xpos;
        last_mouse_y = ypos;
    }

    if (left_mouse_down) {
        yaw += @floatCast(dx * 0.01);
        pitch += @floatCast(dy * 0.01);

        last_mouse_x = xpos;
        last_mouse_y = ypos;
    }
}
