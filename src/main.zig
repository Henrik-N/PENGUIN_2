const std = @import("std");
const builtin = @import("builtin");

const c = @cImport({
    @cInclude("xcb/xcb.h");
    @cInclude("X11/keysym.h");
    @cInclude("X11/XKBlib.h");
    @cInclude("X11/Xlib.h");
    @cInclude("X11/Xlib-xcb.h");
    @cInclude("sys/time.h");
    @cInclude("stdlib.h");
});

const NULL: i32 = 0;
const FALSE: i32 = 0;
const TRUE: i32 = 1;

/// Custom log implementation.
/// Overriding log implementation by defining root.log
pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const inner = struct {
        fn escapeSequence(comptime seq: []const u8) []const u8 {
            return "\x1b[" ++ seq ++ "m";
        }
    };

    const color_prefix = comptime switch (level) {
        .err => inner.escapeSequence("31;1"), // red
        .warn => inner.escapeSequence("1;33"), // yellow
        .info => inner.escapeSequence("1;32"), // green
        .debug => inner.escapeSequence("1;30"), // gray
    };

    const format_colored = comptime color_prefix ++
        format ++
        inner.escapeSequence("0");

    std.log.defaultLog(
        level,
        scope,
        format_colored,
        args,
    );
}

/// Returns absolute time in seconds
pub fn getAbsoluteTime() f64 {
    var now: std.os.system.timespec = undefined;
    std.os.clock_gettime(std.os.CLOCK.MONOTONIC, &now) catch unreachable;
    const nanoseconds_in_seconds = @intToFloat(f64, now.tv_nsec) * 0.0000_0000_1;
    return @intToFloat(f64, now.tv_sec) + nanoseconds_in_seconds;
}

const Window = @import("window.zig").Window;

pub fn main() anyerror!void {
    const window = try Window.init(.{});
    defer window.deinit();

    while (window.pollEvents()) {
        const absolute_time = getAbsoluteTime();
        std.log.debug("absolute time: {}", .{absolute_time});
    }

    // testing log colors
    std.log.info("info", .{});
    std.log.debug("debug", .{});
    std.log.warn("warning", .{});
    std.log.err("error", .{});

    std.log.info("Exit success", .{});
}
