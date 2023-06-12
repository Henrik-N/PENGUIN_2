const std = @import("std");
const builtin = @import("builtin");
const log = std.log.scoped(.window);

const PlatformWindow = switch (builtin.os.tag) {
    .linux => linux.X11Window,
    else => @compileError("Unsupported platform"),
};

pub const Window = struct {
    pub const Config = struct {
        x: i16 = 10,
        y: i16 = 10,
        width: u16 = 800,
        height: u16 = 600,
        title: [:0]const u8 = "PENGUINS",
    };

    platform_window: PlatformWindow,

    pub fn init(config: Config) !Window {
        return Window{
            .platform_window = try PlatformWindow.init(config),
        };
    }

    pub fn deinit(window: Window) void {
        window.platform_window.deinit();
    }

    pub fn pollEvents(window: Window) bool {
        return window.platform_window.pollEvents();
    }

    pub fn getWindowSize(window: Window, width: *i32, height: *i32) !void {
        return window.platform_window.getWindowSize(width, height);
    }
};

const linux = struct {
    const c = @cImport({
        @cInclude("xcb/xcb.h");
        // @cInclude("xcb/xproto.h");
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

    pub const X11Window = struct {
        display: ?*c.Display = null,
        // Xcb connection to X11
        connection: ?*c.xcb_connection_t = null,
        //
        window: c.xcb_window_t,
        screen: ?*c.xcb_screen_t,
        // window message
        wm_protocols: c.xcb_atom_t,
        // window message
        wm_delete_win: c.xcb_atom_t,

        pub fn getWindowSize(window: X11Window, width: *i32, height: *i32) !void {
            if (window.display == null) {
                return error.DisplayIsNull;
            }
            const cookie: c.xcb_get_geometry_cookie_t = c.xcb_get_geometry(window.connection.?, window.window);
            const reply: ?*c.xcb_get_geometry_reply_t = c.xcb_get_geometry_reply(window.connection.?, cookie, null);
            defer c.free(reply);

            if (reply) |r| {
                width.* = r.width;
                height.* = r.height;
                return;
            }

            return error.FailedToGetWindowSize;
        }

        pub fn init(config: Window.Config) !X11Window {
            // Connect to X-server
            const display: ?*c.Display = c.XOpenDisplay(NULL);
            const connection: ?*c.xcb_connection_t = c.XGetXCBConnection(display);
            const has_error = c.xcb_connection_has_error(connection.?);
            if (has_error == TRUE) {
                return error.XServerConnectionError; // failed to connect to X-server through XCB
            }

            // Retrieve setup data from X-server
            const setup: ?*const c.xcb_setup_t = c.xcb_get_setup(connection.?);

            // Loop through the screens and grab one using an iterator (just grabbing the first one right now)
            var screen_it: c.xcb_screen_iterator_t = c.xcb_setup_roots_iterator(setup.?);
            var screen_index: i32 = 0;
            while (screen_index > 0) : (screen_index -= 1) {
                c.xcb_screen_next(&screen_it);
            }
            const screen: ?*c.xcb_screen_t = screen_it.data;

            // Generate XID for the window
            const window: c.xcb_window_t = c.xcb_generate_id(connection.?);

            // Event types

            // Listen for keyboard and mouse button events
            const values: u32 =
                c.XCB_EVENT_MASK_BUTTON_PRESS |
                c.XCB_EVENT_MASK_BUTTON_RELEASE |
                c.XCB_EVENT_MASK_KEY_PRESS |
                c.XCB_EVENT_MASK_KEY_RELEASE |
                c.XCB_EVENT_MASK_EXPOSURE |
                c.XCB_EVENT_MASK_POINTER_MOTION |
                c.XCB_EVENT_MASK_STRUCTURE_NOTIFY;

            // XCB_CW_BACK_PIXEL = fill window with single color
            // XCB_CW_EVENT_MASK = required bit
            const value_mask: u32 = c.XCB_CW_BACK_PIXEL | c.XCB_CW_EVENT_MASK;
            const value_list = [_]u32{
                screen.?.*.black_pixel,
                values,
            };

            // Create window
            _ = c.xcb_create_window(
                connection,
                c.XCB_COPY_FROM_PARENT, // depth, don't need it so just letting it be
                window,
                screen.?.*.root,
                config.x,
                config.y,
                config.width,
                config.height,
                0, // border
                c.XCB_WINDOW_CLASS_INPUT_OUTPUT, // window class, accepting input & output
                @intCast(u16, screen.?.*.root_visual), // id for windows new visual
                value_mask,
                &value_list,
            );

            // Change window title
            _ = c.xcb_change_property(
                connection,
                c.XCB_PROP_MODE_REPLACE, // replace previous value
                window,
                c.XCB_ATOM_WM_NAME,
                c.XCB_ATOM_STRING,
                @bitSizeOf(u8), // read data 8 bits at a time (1 char)
                @intCast(u32, config.title.len),
                config.title.ptr,
            );

            // Tell X-server to send notifications when the window manager tries to destroy
            // the window.
            const atoms = try requestAtoms(connection.?, &.{ "WM_DELETE_WINDOW", "WM_PROTOCOLS" });
            const wm_delete_win_atom = atoms[0];
            const wm_protocols_atom = atoms[1];

            // -----------

            // set replies on window
            _ = c.xcb_change_property(
                connection,
                c.XCB_PROP_MODE_REPLACE,
                window,
                wm_protocols_atom,
                4,
                32,
                1,
                &wm_delete_win_atom,
            );

            // Map window to screen
            _ = c.xcb_map_window(connection, window);

            // Flush the stream, force any output to be written to X-server
            const stream_result = c.xcb_flush(connection);
            if (stream_result <= 0) {
                return error.FailedToFlushStream;
            }

            return X11Window{
                .display = display,
                .connection = connection,
                .window = window,
                .screen = screen,
                //
                .wm_delete_win = wm_delete_win_atom,
                .wm_protocols = wm_protocols_atom,
            };
        }

        pub fn deinit(platform: X11Window) void {
            _ = c.xcb_destroy_window(
                platform.connection.?,
                platform.window,
            );
        }

        pub fn pollEvents(platform: X11Window) bool {
            var should_window_close = false;

            // Process events (returns null when there are no events left)
            while (c.xcb_poll_for_event(platform.connection.?)) |event| {
                // xcb_poll_for_event is dynamically allocating, event needs to be freed
                defer c.free(event);

                // Switch on input events.
                // The first bit signifies the event's origin, don't care about this.
                // ~0x80 = 0111 1111 => removing the first bit
                switch (event.?.*.response_type & ~@intCast(i32, 0x80)) {
                    c.XCB_KEY_PRESS, c.XCB_KEY_RELEASE => {
                        // handle key input
                    },
                    c.XCB_BUTTON_PRESS, c.XCB_BUTTON_RELEASE => {
                        // handle mouse button input
                    },
                    c.XCB_MOTION_NOTIFY => {
                        // mouse movement input
                    },
                    c.XCB_CONFIGURE_NOTIFY => {
                        // window resizing
                    },
                    c.XCB_CLIENT_MESSAGE => {
                        const client_message_event = @ptrCast(?*c.xcb_client_message_event_t, event);

                        if (client_message_event.?.*.data.data32[0] == platform.wm_delete_win) {
                            log.debug("exit request message received, exiting...", .{});
                            should_window_close = true;
                            break;
                        }
                    },
                    else => {},
                }
            }

            return !should_window_close;
        }
    };

    fn requestAtoms(connection: ?*c.xcb_connection_t, comptime atom_names: []const [:0]const u8) ![atom_names.len]c.xcb_atom_t {
        const atom_count = atom_names.len;

        var cookies: [atom_count]c.xcb_intern_atom_cookie_t = undefined;

        // request atom identifiers for the event's we want to listen to
        for (atom_names, 0..) |atom_name, index| {
            cookies[index] = c.xcb_intern_atom(
                connection.?,
                0,
                @intCast(u16, atom_name.len),
                atom_name.ptr,
            );
        }

        // get atom replies
        var atom_replies: [atom_count]?*c.xcb_intern_atom_reply_t = undefined;
        for (cookies, 0..) |cookie, index| {
            atom_replies[index] = c.xcb_intern_atom_reply(
                connection.?,
                cookie,
                NULL,
            );
        }
        defer for (atom_replies) |reply| if (reply) |r| c.free(r);

        // get atoms, crash if unavailable
        var atoms: [atom_count]c.xcb_atom_t = undefined;
        for (atom_replies, 0..) |reply_, index| {
            const reply = reply_ orelse return error.AtomReplyMissing;
            atoms[index] = reply.*.atom;
        }

        return atoms;
    }
};
