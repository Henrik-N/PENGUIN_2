const builtin = @import("builtin");
const Window = @import("window.zig").Window;
const vulkan_types = @import("vulkan_types.zig");
const vk = vulkan_types.vk;
const VulkanInstance = vulkan_types.VulkanInstance;

pub fn createSurface(instance: VulkanInstance, window: Window) !vk.SurfaceKHR {
    comptime switch (builtin.os.tag) {
        .linux => {},
        else => @compileError("surface creation not implemented for " ++ @tagName(builtin.os.tag)),
    };

    const create_info = vk.XcbSurfaceCreateInfoKHR{
        .flags = .{},
        .connection = window.con.connection,
        .window = window.window_id,
    };

    return try instance.createXcbSurfaceKHR(&create_info, null);
}
