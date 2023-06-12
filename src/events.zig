const std = @import("std");
const Window = @import("window.zig").Window;

const c = @cImport({
    @cInclude("xcb/xcb.h");
});

pub const PlatformEvents = struct {
    should_exit: bool = false,
    window_resize: ?struct {
        width: u32,
        height: u32,
    } = null,

    fn reset(self: *@This()) void {
        self.should_exit = false;
        self.window_resize = null;
    }
};

pub fn pollPlatformEvents(window: Window, out_events: *PlatformEvents) !void {
    out_events.reset();

    while (true) {
        const event: *c.xcb_generic_event_t = c.xcb_poll_for_event(window.con.connection) orelse break;
        defer std.heap.raw_c_allocator.destroy(event); // xcb allocates the events with malloc

        switch (event.response_type & ~@as(i32, 0x80)) {
            c.XCB_CONFIGURE_NOTIFY => {
                const configure_event = @ptrCast(*c.xcb_configure_notify_event_t, event);

                out_events.window_resize = .{
                    .width = configure_event.width,
                    .height = configure_event.height,
                };
            },
            c.XCB_CLIENT_MESSAGE => {
                const client_message_event = @ptrCast(*c.xcb_client_message_event_t, event);

                if (client_message_event.data.data32[0] == window.delete_window_atom) {
                    out_events.should_exit = true;
                    break;
                }
            },
            c.XCB_EVENT_MASK_KEY_RELEASE => {
                const key_event = @ptrCast(*c.xcb_key_press_event_t, event);
                _ = key_event;
            },
            c.XCB_EVENT_MASK_BUTTON_PRESS => {},
            c.XCB_EVENT_MASK_BUTTON_RELEASE => {},
            c.XCB_EVENT_MASK_POINTER_MOTION => {},
            c.XCB_EVENT_MASK_STRUCTURE_NOTIFY => {},
            c.XCB_EXPOSE => {},
            else => {},
        }
    }
}
