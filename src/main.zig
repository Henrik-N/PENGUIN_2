const std = @import("std");
const builtin = @import("builtin");

const Window = @import("window.zig").Window;
const Timer = std.time.Timer;
const Renderer = @import("renderer.zig").Renderer;

const events = @import("events.zig");

const c = @cImport({
    @cInclude("xcb/xcb.h");
});

// defined in root for vulkan-zig
pub const xcb_connection_t = c.xcb_connection_t;
pub const xcb_window_t = c.xcb_window_t;

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

const TimeTicker = struct {
    clock: Timer,
    last_time: u64,
    fps_limit: f64,

    pub fn init(fps_limit: f64) !TimeTicker {
        var clock = try Timer.start();
        const last_time = clock.read();

        return TimeTicker{
            .clock = clock,
            .last_time = last_time,
            .fps_limit = fps_limit,
        };
    }

    pub fn tick(self: *TimeTicker) f64 {
        var now: u64 = self.clock.read();
        var delta_time: u64 = now - self.last_time;

        if (self.fps_limit > 0.0) {
            const min_delta_time: u64 = secondsToNanoSeconds(1.0 / self.fps_limit);
            const remaining_ns_to_min_dt: u64 = min_delta_time - delta_time;
            if (remaining_ns_to_min_dt > 0) {
                std.time.sleep(remaining_ns_to_min_dt);
            }

            now = self.clock.read();
            delta_time = now - self.last_time;
        }
        self.last_time = now;

        return nanosecondsToSeconds(delta_time);
    }

    fn nanosecondsToSeconds(ns: u64) f64 {
        return @intToFloat(f64, ns) / @intToFloat(f64, std.time.ns_per_s);
    }

    fn secondsToNanoSeconds(s: f64) u64 {
        return @floatToInt(u64, s * std.time.ns_per_s);
    }
};

pub fn main() anyerror!void {
    const window = try Window.init(.{
        .x = 10,
        .y = 10,
        .width = 800,
        .height = 600,
    });
    defer window.deinit();

    var renderer = try Renderer.init(window);
    defer renderer.deinit();

    var game = Game{};
    var game_tick = try TimeTicker.init(60.0);

    var platform_events = events.PlatformEvents{};

    while (true) {
        try events.pollPlatformEvents(window, &platform_events);

        if (platform_events.should_exit) {
            break;
        }

        const dt = game_tick.tick();

        const delta_time = @floatCast(f32, dt);
        {
            game.update(delta_time) catch |e| {
                std.log.err("game update failed with error: {}", .{e});
                return e;
            };

            game.render(delta_time) catch |e| {
                std.log.err("game render failed with error: {}", .{e});
                return e;
            };

            try renderer.renderFrame(.{
                .delta_time = delta_time,
            });
        }
    }

    std.log.info("Exit success", .{});
}
