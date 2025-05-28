const std = @import("std");

const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});
const gl = @cImport({
    @cInclude("GL/gl.h");
});
const ass = @cImport({
    @cInclude("assimp/cimport.h");
    @cInclude("assimp/scene.h");
    @cInclude("assimp/postprocess.h");
});

pub fn project2() !void {
    const filename = "assets/teapot.obj";
    const scene = ass.aiImportFile(filename, ass.aiProcessPreset_TargetRealtime_MaxQuality);
    if (scene == null) {
        std.debug.print("Failed to load teapot: {s}\n", .{ass.aiGetErrorString()});
        return;
    }
    defer ass.aiReleaseImport(scene);
    std.debug.print("Meshes: {d}\n", .{scene.*.mNumMeshes});
    for (scene.*.mMeshes[0..scene.*.mNumMeshes]) |mesh| {
        std.debug.print("Mesh has {d} vertices\n", .{mesh.*.mNumVertices});
        for (mesh.*.mVertices[0..mesh.*.mNumVertices], 0..) |vertex, i| {
            const x = vertex.x;
            const y = vertex.y;
            const z = vertex.z;
            std.debug.print("Vertex {d}: ({d}, {d}, {d})\n", .{ i, x, y, z });
        }
    }

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
