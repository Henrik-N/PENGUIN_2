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
        .connection = window.platform_window.connection orelse return error.XcbConnectionNull,
        .window = window.platform_window.window,
    };

    return try instance.vki.createXcbSurfaceKHR(instance.handle, &create_info, null);
}
