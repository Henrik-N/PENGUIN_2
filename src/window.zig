const std = @import("std");
const log = std.log;
const print = std.debug.print;

const c = @cImport({
    @cInclude("xcb/xcb.h");
});

pub const WindowProps = struct {
    x: i16,
    y: i16,
    width: u16,
    height: u16,
};

pub const Window = struct {
    con: XcbConnection,
    window_id: c.xcb_window_t,
    delete_window_atom: c.xcb_atom_t,

    pub fn deinit(window: Window) void {
        window.con.disconnect();
    }

    pub fn init(props: WindowProps) !Window {
        const con = try XcbConnection.connect();
        errdefer con.disconnect();

        const window_id = createWindow(con, props);
        changeWindowTitle(con, window_id, "Pengine");
        mapWindow(con, window_id);

        const delete_window_atom = blk: {
            const window_protocols_cookie = con.requestInternAtom("WM_PROTOCOLS");
            const delete_window_cookie = con.requestInternAtom("WM_DELETE_WINDOW");

            const window_protocols_reply = con.recvInternAtomReply(window_protocols_cookie).?;
            const delete_window_reply = con.recvInternAtomReply(delete_window_cookie).?;

            _ = c.xcb_change_property(con.connection, c.XCB_PROP_MODE_REPLACE, window_id, window_protocols_reply.atom, 4, 32, 1, &delete_window_reply.atom);
            break :blk delete_window_reply.atom;
        };

        try con.flush();

        return .{
            .con = con,
            .window_id = window_id,
            .delete_window_atom = delete_window_atom,
        };
    }

    pub fn getWindowSize(window: Window, width: *i32, height: *i32) !void {
        const cookie: c.xcb_get_geometry_cookie_t = c.xcb_get_geometry(window.con.connection, window.window_id);
        const reply: ?*c.xcb_get_geometry_reply_t = c.xcb_get_geometry_reply(window.con.connection, cookie, null);
        defer if (reply) |r| std.heap.raw_c_allocator.destroy(r);

        if (reply) |r| {
            width.* = r.width;
            height.* = r.height;
            return;
        }

        return error.FailedToGetWindowSize;
    }

    pub fn setWindowSize(con: XcbConnection, window_id: c.xcb_window_t, _: WindowProps) void {
        const mask: u16 =
            c.XCB_CONFIG_WINDOW_X |
            c.XCB_CONFIG_WINDOW_Y |
            c.XCB_CONFIG_WINDOW_WIDTH |
            c.XCB_CONFIG_WINDOW_HEIGHT;

        const values = [_]u32{ 10, 10, 800, 600 };

        _ = c.xcb_configure_window(con.connection, window_id, mask, &values);
    }
};

const XcbConnection = struct {
    connection: *c.xcb_connection_t,
    screen: *c.xcb_screen_t,

    const XcbError = error{
        Connect,
        GetScreen,
        Flush,
    };

    fn disconnect(self: @This()) void {
        _ = c.xcb_disconnect(self.connection);
    }

    fn connect() XcbError!XcbConnection {
        // Connect to the X11 server. Passing null as display name grabs the name from the $DISPLAY environment variable.
        var screen_index: i32 = 0;
        const connection: *c.xcb_connection_t = c.xcb_connect(null, &screen_index) orelse return XcbError.Connect;
        errdefer _ = c.xcb_disconnect(connection);

        // Fetch xcb screen object
        const screen: *c.xcb_screen_t = blk: {
            const setup: *const c.xcb_setup_t = c.xcb_get_setup(connection);
            var screen_iter: c.xcb_screen_iterator_t = c.xcb_setup_roots_iterator(setup);
            var i: i32 = 0;
            while (i < screen_index) : (i += 1) c.xcb_screen_next(&screen_iter);
            break :blk screen_iter.data orelse return XcbError.GetScreen;
        };

        return .{
            .connection = connection,
            .screen = screen,
        };
    }

    /// Clear xcb-internal write buffer and send all pending requests to the X11 server
    fn flush(self: @This()) XcbError!void {
        const result = c.xcb_flush(self.connection);
        if (result < 1) {
            return XcbError.Flush;
        }
    }

    fn requestInternAtom(con: XcbConnection, atom_name: []const u8) c.xcb_intern_atom_cookie_t {
        return c.xcb_intern_atom(con.connection, 0, @intCast(u16, atom_name.len), atom_name.ptr);
    }

    fn recvInternAtomReply(con: XcbConnection, request_cookie: c.xcb_intern_atom_cookie_t) ?*c.xcb_intern_atom_reply_t {
        return c.xcb_intern_atom_reply(con.connection, request_cookie, null);
    }
};

/// Window creation request
fn createWindow(con: XcbConnection, window_props: WindowProps) c.xcb_window_t {
    const window_id: c.xcb_window_t = c.xcb_generate_id(con.connection);

    const event_mask =
        c.XCB_EVENT_MASK_BUTTON_PRESS |
        c.XCB_EVENT_MASK_BUTTON_RELEASE |
        c.XCB_EVENT_MASK_KEY_PRESS |
        c.XCB_EVENT_MASK_KEY_RELEASE |
        c.XCB_EVENT_MASK_EXPOSURE |
        c.XCB_EVENT_MASK_POINTER_MOTION |
        c.XCB_EVENT_MASK_STRUCTURE_NOTIFY;

    const mask: u32 = c.XCB_CW_BACK_PIXEL | c.XCB_CW_EVENT_MASK;
    const values = [_]u32{ con.screen.black_pixel, event_mask };

    _ = c.xcb_create_window(
        con.connection,
        con.screen.root_depth,
        window_id,
        con.screen.root,
        window_props.x,
        window_props.y,
        window_props.width,
        window_props.height,
        10,
        c.XCB_WINDOW_CLASS_INPUT_OUTPUT,
        con.screen.root_visual,
        mask,
        &values,
    );

    return window_id;
}

/// Display window resquest
fn mapWindow(con: XcbConnection, window: c.xcb_window_t) void {
    _ = c.xcb_map_window(con.connection, window);
}

fn changeWindowTitle(con: XcbConnection, window: c.xcb_window_t, title: []const u8) void {
    _ = c.xcb_change_property(
        con.connection,
        c.XCB_PROP_MODE_REPLACE,
        window,
        c.XCB_ATOM_WM_NAME,
        c.XCB_ATOM_STRING,
        @sizeOf(u8) * 8, // should be read 8 bits at a time
        @intCast(u32, title.len),
        title.ptr,
    );
}
