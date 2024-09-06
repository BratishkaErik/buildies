// SPDX-FileCopyrightText: 2024 Eric Joldasov
//
// SPDX-License-Identifier: 0BSD

const std = @import("std");
const all = @import("build/all.zig");

pub const Wrapper = all.Wrapper;
pub const Module = all.Module;

pub fn wrap(
    comptime build_fn: fn (Wrapper) anyerror!void,
) fn (*std.Build) anyerror!void {
    return (struct {
        fn build(b: *std.Build) !void {
            const wrapper: Wrapper = .{
                .b = b,
                .artifact = .{},
            };
            try build_fn(wrapper);
        }
    }).build;
}

// Example of enabling wrapping:
pub const build = wrap(configure);

pub fn configure(w: Wrapper) !void {
    _ = w;
}
