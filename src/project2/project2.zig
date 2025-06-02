const std = @import("std");

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
    \\void main() {
    \\    gl_Position = vec4(aPos, 1.0);
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

pub fn project2() !void {
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

    const view = 20; //TODO remove
    for (mesh.*.mVertices[0..num_verticies], 0..) |v, i| {
        float_vertices[i * 3 + 0] = v.x / view;
        float_vertices[i * 3 + 1] = v.y / view;
        float_vertices[i * 3 + 2] = v.z / view;
    }

    for (float_vertices) |fv| {
        std.debug.print("{}\n", .{fv});
    }

    if (glfw.glfwInit() == glfw.GLFW_FALSE) {
        std.debug.print("GLFW failed to load.\n", .{});
        return;
    }

    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);

    const window = glfw.glfwCreateWindow(1024, 768, "CS5610", null, null);
    if (window == null) {
        std.debug.print("Window failed to create.\n", .{});
        return error.WindowCreationFailed;
    }
    _ = glfw.glfwSetFramebufferSizeCallback(window, framebufferSizeCallback);

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

    while (glfw.glfwWindowShouldClose(window) != glfw.GLFW_TRUE) {
        if (glfw.glfwGetKey(window, glfw.GLFW_KEY_ESCAPE) == glfw.GLFW_PRESS) {
            glfw.glfwSetWindowShouldClose(window, glfw.GLFW_TRUE);
        }

        gl.glClearColor(0.1, 0.1, 0.1, 1.0);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);

        glad.glUseProgram(shader_program);
        glad.glBindVertexArray(vao);
        glad.glDrawArrays(gl.GL_POINTS, 0, @intCast(num_verticies));

        glfw.glfwSwapBuffers(window);
        glfw.glfwPollEvents();
    }
}

fn createShader(kind: gl.GLenum, src: []const u8) !gl.GLuint {
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
    glfw.glViewport(0, 0, width, height);
}
