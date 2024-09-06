// SPDX-FileCopyrightText: 2025 Eric Joldasov
//
// SPDX-License-Identifier: 0BSD

const std = @import("std");

pub fn main() error{OutOfMemory}!void {
    const context = .{
        .name = @import("project_settings").name,
        .version = @import("project_settings").version,

        .zig_version = @import("builtin").zig_version,
        .zig_target = try @import("builtin").target.zigTriple(std.heap.smp_allocator),
    };

    std.debug.print(
        \\Hello, world!
        \\
        \\Information about project:
        \\ * Name:    {[name]s}
        \\ * Version: {[version]}
        \\
        \\Information about compilation:
        \\ * Zig version: {[zig_version]}
        \\ * Full target: {[zig_target]s}
        \\
    , context);
}
