const std = @import("std");

const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});
const gl = @cImport({
    @cInclude("GL/gl.h");
});

pub fn project1() !void {
    if (glfw.glfwInit() == glfw.GLFW_FALSE) {
        std.debug.print("GLFW failed to load.\n", .{});
        return;
    }

    const window = glfw.glfwCreateWindow(640, 480, "CS5610", null, null);
    if (window == null) {
        std.debug.print("Window failed to create.\n", .{});
        return error.WindowCreationFailed;
    }

    glfw.glfwMakeContextCurrent(window);

    defer glfw.glfwTerminate();
    defer glfw.glfwDestroyWindow(window);

    while (glfw.glfwWindowShouldClose(window) != glfw.GLFW_TRUE) {
        if (glfw.glfwGetKey(window, glfw.GLFW_KEY_ESCAPE) == glfw.GLFW_PRESS) {
            glfw.glfwSetWindowShouldClose(window, glfw.GLFW_TRUE);
        }

        gl.glClearColor(0.2, 0.3, 0.3, 1.0);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);
        glfw.glfwSwapBuffers(window);
        glfw.glfwPollEvents();
    }
}
