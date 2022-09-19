const std = @import("std");
const builtin = @import("builtin");

const Window = @import("window.zig").Window;
const Timer = std.time.Timer;

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

const Game = struct {
    pub fn update(game: *Game, dt: f32) !void {
        _ = game;
        _ = dt;
    }

    pub fn render(game: *Game, dt: f32) !void {
        _ = game;
        _ = dt;
    }
};

fn nanosecondsToSeconds(ns: u64) f64 {
    return @intToFloat(f64, ns) / @intToFloat(f64, std.time.ns_per_s);
}

fn secondsToNanoSeconds(s: f64) u64 {
    return @floatToInt(u64, s * std.time.ns_per_s);
}

const FpsThrottler = struct {
    const Config = struct {
        should_cap_fps: bool = true,
        max_frames_per_second: f64 = 60.0,
    };

    frame_duration_timer: Timer,
    config: Config,

    fn init(config: Config) !FpsThrottler {
        return FpsThrottler{
            .frame_duration_timer = try Timer.start(),
            .config = config,
        };
    }

    fn beginFrame(throttler: *FpsThrottler) void {
        throttler.frame_duration_timer.reset();
    }

    fn endFrame(throttler: FpsThrottler) void {
        if (throttler.config.should_cap_fps) {
            const frame_elapsed_time = throttler.frame_duration_timer.read();
            const target_fps_ns = secondsToNanoSeconds(1.0 / throttler.config.max_frames_per_second);
            const remaining_ns: u64 = target_fps_ns - frame_elapsed_time;
            if (remaining_ns > 0) {
                std.time.sleep(remaining_ns);
            }
        }
    }
};

pub fn main() anyerror!void {
    var fps_throttler = try FpsThrottler.init(.{});
    var game = Game{};

    const window = try Window.init(.{});
    defer window.deinit();

    const clock = try Timer.start();
    var last_time: u64 = clock.read();

    var passed_time: f64 = 0;

    while (window.pollEvents()) {
        const now: u64 = clock.read();
        const dt: f64 = nanosecondsToSeconds(now - last_time);
        last_time = now;

        {
            passed_time += dt;
            std.log.info("Now: {d:.2}", .{passed_time});
        }

        {
            fps_throttler.beginFrame();
            defer fps_throttler.endFrame();

            game.update(@floatCast(f32, dt)) catch |e| {
                std.log.err("game update failed with error: {}", .{e});
                return e;
            };

            game.render(@floatCast(f32, dt)) catch |e| {
                std.log.err("game render failed with error: {}", .{e});
                return e;
            };
        }

        // input
    }

    std.log.info("Exit success", .{});
}
