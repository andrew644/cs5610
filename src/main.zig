const std = @import("std");

const project1 = @import("project1/project1.zig");
const project2 = @import("project2/project2.zig");
const project3 = @import("project3/project3.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        //run latest project
        _ = try project3.project3();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "project1")) {
        _ = try project1.project1();
    } else if (std.mem.eql(u8, command, "project2")) {
        _ = try project2.project2();
    } else if (std.mem.eql(u8, command, "project3")) {
        _ = try project3.project3();
    } else {
        std.debug.print("Unknown project: {s}\n", .{command});
    }
}
