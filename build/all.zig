// SPDX-FileCopyrightText: 2025 Eric Joldasov
//
// SPDX-License-Identifier: 0BSD

const std = @import("std");

pub const Wrapper = struct {
    b: *std.Build,
    artifact: struct {
        pub fn object(this: *const @This()) *std.Build.Step.Compile {
            const w: *const Wrapper = @alignCast(@fieldParentPtr("artifact", this));

            return w.b.addObject(.{
                .name = "TODO",
                .root_module = w.b.createModule(.{
                    .target = w.b.resolveTargetQuery(.{}),
                    .optimize = .ReleaseSmall,
                }),
            });
        }
    },

    pub fn find_project(w: Wrapper) !Project {
        const project_root = w.b.build_root.handle;
        const allocator = w.b.allocator;

        const zon_file = try project_root.readFileAllocOptions(
            allocator,
            "build.zig.zon",
            10 * 1024 * 1024,
            null,
            std.mem.Alignment.of(u8),
            0,
        );

        const Manifest = struct {
            name: std.zig.Zoir.Node.Index,
            version: []const u8,
        };

        var diag: std.zon.parse.Diagnostics = .{};

        const zon = try std.zon.parse.fromSlice(
            Manifest,
            allocator,
            zon_file,
            &diag,
            .{ .ignore_unknown_fields = true },
        );

        const name = switch (zon.name.get(diag.zoir)) {
            .enum_literal => |enum_literal| enum_literal.get(diag.zoir),
            else => @panic("TODO"),
        };
        const version = try std.SemanticVersion.parse(zon.version);

        return .{
            .name = name,
            .version = version,
            .internal = .{
                .owner = w,
            },
        };
    }

    const ProjectCreationOptions = struct {
        name: []const u8,
        version: std.SemanticVersion,
    };
    pub fn create_project(w: Wrapper, options: ProjectCreationOptions) Project {
        return .{
            .name = options.name,
            .version = options.version,
            .internal = .{
                .owner = w,
            },
        };
    }
};

pub const Visibility = enum(u1) {
    public,
    private,
};

pub const Project = struct {
    name: []const u8,
    version: std.SemanticVersion,

    internal: struct {
        owner: Wrapper,
    },

    pub const ModuleCreationOptions = struct {
        name: ?[]const u8 = null,
        //version: ?std.SemanticVersion,

        source_file: ?std.Build.LazyPath,
        target: union(enum) {
            any,
            forced: std.Build.ResolvedTarget,
            filter: *const fn (std.Target.Query) error{NotSupported}!std.Target.Query,
            // allow_list: []const u8,
            // block_list: []const u8,
        } = .any,
        optimize: union(enum) {
            any,
            forced: std.builtin.OptimizeMode,
            filter: *const fn (std.builtin.OptimizeMode) error{NotSupported}!std.builtin.OptimizeMode,
        } = .any,
    };
    pub fn create_module(project: Project, visibility: Visibility, options: ModuleCreationOptions) Module {
        const b = project.internal.owner.b;

        const name = options.name orelse project.name;

        const target = switch (options.target) {
            .any => b.standardTargetOptions(.{}),
            .forced => |forced_target| forced_target,
            .filter => |filter_fn| filtered: {
                const query_passed = b.standardTargetOptionsQueryOnly(.{});
                const query_filtered = filter_fn(query_passed) catch @panic("TODO query not supported");

                const target_filtered = b.resolveTargetQuery(query_filtered);
                break :filtered target_filtered;
            },
        };
        const optimize = switch (options.optimize) {
            .any => b.standardOptimizeOption(.{}),
            .forced => |forced_optimize| forced_optimize,
            .filter => |filter_fn| filtered: {
                const optimize_passed = b.standardOptimizeOption(.{});
                const optimize_filtered = filter_fn(optimize_passed) catch @panic("TODO optimize mode not supported");

                break :filtered optimize_filtered;
            },
        };

        const mod_internal = std.Build.Module.create(b, .{
            .root_source_file = options.source_file,
            .target = target,
            .optimize = optimize,
            .pic = true,
        });

        const project_settings = b.addOptions();
        project_settings.addOption([]const u8, "name", project.name);
        project_settings.addOption(std.SemanticVersion, "version", project.version);
        mod_internal.addOptions("project_settings", project_settings);

        switch (visibility) {
            .public => {
                b.modules.put(name, mod_internal) catch @panic("OOM");
            },
            .private => {},
        }

        return .{
            .name = name,

            .internal = .{
                .owner = project.internal.owner,
                .module = mod_internal,
            },
        };
    }

    pub fn path(project: Project, relative_path: []const u8) std.Build.LazyPath {
        const b = project.internal.owner.b;

        return b.path(relative_path);
    }
};

pub const Module = struct {
    name: []const u8,

    internal: struct {
        owner: Wrapper,
        module: *std.Build.Module,
    },

    pub fn compile_executable(module: Module) Artifact {
        const artifact = module.internal.owner.b.addExecutable(.{
            .name = module.name,
            .root_module = module.internal.module,
        });

        return .{
            .internal = .{
                .owner = module.internal.owner,
                .artifact = artifact,
            },
        };
    }

    pub fn allow_tests(module: Module) void {
        const b = module.internal.owner.b;
        const step = b.step("test", "Run unit tests");

        const test_artifact = b.addTest(.{
            .name = module.name,
            .root_module = module.internal.module,
        });

        const run_tests = b.addRunArtifact(test_artifact);

        step.dependOn(&run_tests.step);
    }
};

pub const Artifact = struct {
    internal: struct {
        owner: Wrapper,
        artifact: *std.Build.Step.Compile,
    },

    pub fn install(artifact: Artifact) void {
        const b = artifact.internal.owner.b;

        const install_sub_step = std.Build.Step.InstallArtifact.create(b, artifact.internal.artifact, .{});
        b.getInstallStep().dependOn(&install_sub_step.step);
    }

    pub fn allow_run(artifact: Artifact) void {
        const b = artifact.internal.owner.b;
        const step = b.step("run", "Run the app");

        const run_cmd = b.addRunArtifact(artifact.internal.artifact);
        run_cmd.addArgs(b.args orelse &.{});

        run_cmd.step.dependOn(b.getInstallStep());
        step.dependOn(&run_cmd.step);
    }
};
