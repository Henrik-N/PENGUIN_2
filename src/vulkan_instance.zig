const std = @import("std");
const builtin = @import("builtin");
const log = std.log.scoped(.vulkan_instance);
const vulkan_types = @import("vulkan_types.zig");
const vk = vulkan_types.vk;
const VulkanEntry = vulkan_types.VulkanEntry;

const is_debug_build = builtin.mode == std.builtin.Mode.Debug;

const InstanceDispatch = vk.InstanceWrapper(.{
    .destroyInstance = true,
    .createDebugUtilsMessengerEXT = true,
    .destroyDebugUtilsMessengerEXT = true,
    .createXcbSurfaceKHR = builtin.os.tag == .linux,
    .destroySurfaceKHR = true,

    .enumeratePhysicalDevices = true,
    .enumerateDeviceExtensionProperties = true,

    .getPhysicalDeviceSurfaceFormatsKHR = true,
    .getPhysicalDeviceSurfacePresentModesKHR = true,
    .getPhysicalDeviceSurfaceCapabilitiesKHR = true,

    .getPhysicalDeviceProperties = true,
    .getPhysicalDeviceQueueFamilyProperties = true,
    .getPhysicalDeviceSurfaceSupportKHR = true,
    .getPhysicalDeviceMemoryProperties = true,
    .getPhysicalDeviceFeatures = true,

    .createDevice = true,
    .getDeviceProcAddr = true,
});

pub const VulkanInstance = struct {
    handle: vk.Instance,
    vki: InstanceDispatch,

    pub fn deinit(instance: VulkanInstance) void {
        instance.vki.destroyInstance(instance.handle, null);
    }

    pub fn init(entry: VulkanEntry, layers: []const [*:0]const u8, extensions: []const [*:0]const u8) !VulkanInstance {
        const instance = try initInstance(entry, layers, extensions);
        const vki = InstanceDispatch.load(instance, entry.loader_fn) catch |e| {
            log.err("Instance dispatch load failure {}", .{e});
            return e;
        };
        errdefer vki.destroyInstance(instance, null);

        return VulkanInstance{
            .handle = instance,
            .vki = vki,
        };
    }
};

fn initInstance(entry: VulkanEntry, layers: []const [*:0]const u8, extensions: []const [*:0]const u8) !vk.Instance {
    const app_info = vk.ApplicationInfo{
        .p_application_name = "Penguin game",
        .application_version = vk.makeApiVersion(0, 0, 0, 0),
        .p_engine_name = "Penguin engine",
        .engine_version = vk.makeApiVersion(0, 0, 0, 0),
        .api_version = vk.API_VERSION_1_2,
    };

    return entry.vkb.createInstance(&.{
        .flags = .{},
        .p_application_info = &app_info,
        .enabled_layer_count = @intCast(u32, layers.len),
        .pp_enabled_layer_names = @ptrCast([*]const [*:0]const u8, layers.ptr),
        .enabled_extension_count = @intCast(u32, extensions.len),
        .pp_enabled_extension_names = @ptrCast([*]const [*:0]const u8, extensions.ptr),
    }, null);
}
