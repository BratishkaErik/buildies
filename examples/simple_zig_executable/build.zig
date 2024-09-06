// SPDX-FileCopyrightText: 2025 Eric Joldasov
//
// SPDX-License-Identifier: 0BSD

const std = @import("std");
const buildies = @import("buildies");

pub const build = buildies.wrap(configure1);
//pub const build = buildies.wrap(configure2);

pub fn configure1(w: buildies.Wrapper) !void {
    const project = try w.find_project();

    const mod = project.create_module(.private, .{
        .source_file = project.path("src/main.zig"),
    });
    mod.allow_tests();

    const example = mod.compile_executable();
    example.install();
    example.allow_run();
}

pub fn configure2(w: buildies.Wrapper) !void {
    const project = w.create_project(.{
        .name = "example",
        .version = try std.SemanticVersion.parse("0.1.0"),
    });

    const mod = project.create_module(.private, .{
        .name = "example",
        .source_file = project.path("src/main.zig"),
        .target = .any,
        .optimize = .any,
    });
    mod.allow_tests();

    const example = mod.compile_executable();
    example.install();
    example.allow_run();

    _ = w.artifact.object();
}
