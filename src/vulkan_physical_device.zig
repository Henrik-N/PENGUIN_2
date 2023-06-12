const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.vulkan_physical_device);

const vulkan_types = @import("vulkan_types.zig");
const VulkanInstance = vulkan_types.VulkanInstance;
const vk = vulkan_types.vk;

pub const PhysicalDeviceRequirements = struct {
    queues: struct {
        graphics: bool = false,
        present: bool = false,
        compute: bool = false,
        transfer: bool = false,
    },
    extensions: []const [*:0]const u8 = &.{},
};

pub const SwapchainSupportInfo = struct {
    surface_capabilities: vk.SurfaceCapabilitiesKHR,
    surface_formats: []vk.SurfaceFormatKHR,
    present_modes: []vk.PresentModeKHR,

    ///Returned struct owns the allocated memory.
    pub fn initGet(
        allocator: Allocator,
        instance: VulkanInstance,
        pd: vk.PhysicalDevice,
        surface: vk.SurfaceKHR,
    ) !SwapchainSupportInfo {
        const surface_capabilities = try instance.vki.getPhysicalDeviceSurfaceCapabilitiesKHR(pd, surface);

        var count: u32 = 0;

        _ = try instance.vki.getPhysicalDeviceSurfaceFormatsKHR(pd, surface, &count, null);
        const surface_formats = try allocator.alloc(vk.SurfaceFormatKHR, count);
        errdefer allocator.free(surface_formats);
        _ = try instance.vki.getPhysicalDeviceSurfaceFormatsKHR(pd, surface, &count, surface_formats.ptr);

        count = 0;

        _ = try instance.vki.getPhysicalDeviceSurfacePresentModesKHR(pd, surface, &count, null);
        const present_modes = try allocator.alloc(vk.PresentModeKHR, count);
        errdefer allocator.free(present_modes);
        _ = try instance.vki.getPhysicalDeviceSurfacePresentModesKHR(pd, surface, &count, present_modes.ptr);

        return SwapchainSupportInfo{
            .surface_capabilities = surface_capabilities,
            .surface_formats = surface_formats,
            .present_modes = present_modes,
        };
    }

    pub fn deinit(info: SwapchainSupportInfo, allocator: Allocator) void {
        allocator.free(info.surface_formats);
        allocator.free(info.present_modes);
    }
};

pub const PhysicalDeviceInfo = struct {
    properties: vk.PhysicalDeviceProperties,
    features: vk.PhysicalDeviceFeatures,
    memory: vk.PhysicalDeviceMemoryProperties,

    pub fn get(instance: VulkanInstance, pd: vk.PhysicalDevice) PhysicalDeviceInfo {
        return PhysicalDeviceInfo{
            .properties = instance.vki.getPhysicalDeviceProperties(pd),
            .features = instance.vki.getPhysicalDeviceFeatures(pd),
            .memory = instance.vki.getPhysicalDeviceMemoryProperties(pd),
        };
    }

    pub fn format(
        info: PhysicalDeviceInfo,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        const props = info.properties;

        try writer.print("\n\t{s}\n", .{props.device_name});
        try writer.print("\tVulkan version:\t\t {}.{}.{}\n", .{
            vk.apiVersionMajor(props.api_version),
            vk.apiVersionMinor(props.api_version),
            vk.apiVersionPatch(props.api_version),
        });
        try writer.print("\tGpu driver version:\t {}.{}.{}\n", .{
            vk.apiVersionMajor(props.driver_version),
            vk.apiVersionMinor(props.driver_version),
            vk.apiVersionPatch(props.driver_version),
        });

        const memory_heaps = info.memory.memory_heaps[0..info.memory.memory_heap_count];

        try writer.print("\tMemory heaps:\n", .{});

        for (memory_heaps, 0..) |heap_info, index| {
            const megabytes = @intToFloat(f32, heap_info.size) / 1024.0 / 1024.0;

            if (heap_info.flags.contains(vk.MemoryHeapFlags{ .device_local_bit = true })) {
                try writer.print("\t\t{}: device local \t{d:.2} MB\n", .{ index, megabytes });
            } else {
                try writer.print("\t\t{}: system shared \t{d:.2} MB\n", .{ index, megabytes });
            }
        }
    }
};

pub const QueueFamilyIndices = struct {
    graphics: ?u32 = null,
    present: ?u32 = null,
    compute: ?u32 = null,
    transfer: ?u32 = null,

    fn hasSurfaceSupport(instance: VulkanInstance, pd: vk.PhysicalDevice, queue_family: u32, surface: vk.SurfaceKHR) !bool {
        return (try instance.vki.getPhysicalDeviceSurfaceSupportKHR(pd, queue_family, surface)) == vk.TRUE;
    }

    /// Memory owned and freed by function.
    pub fn find(
        instance: VulkanInstance,
        pd: vk.PhysicalDevice,
        surface: ?vk.SurfaceKHR,
        allocator: Allocator,
    ) !QueueFamilyIndices {
        const family_properties = blk: {
            var count: u32 = 0;
            instance.vki.getPhysicalDeviceQueueFamilyProperties(pd, &count, null);

            const properties = try allocator.alloc(vk.QueueFamilyProperties, count);
            errdefer allocator.free(properties);
            instance.vki.getPhysicalDeviceQueueFamilyProperties(pd, &count, properties.ptr);

            break :blk properties;
        };
        defer allocator.free(family_properties);

        var indices = QueueFamilyIndices{};

        // Increase the likelihood of getting a dedicated transfer queue
        // by trying to get it on a family with few or no other queues.
        var min_transfer_score: u8 = 255;

        for (family_properties, 0..) |family_props, index| {
            var transfer_score: u8 = 0;

            if (indices.present == null and
                surface != null and
                try hasSurfaceSupport(instance, pd, @intCast(u32, index), surface.?))
            {
                indices.present = @intCast(u32, index);
            }

            if (family_props.queue_flags.graphics_bit) {
                indices.graphics = @intCast(u32, index);

                transfer_score +%= 1;

                // Prefer same queue family for present.
                if (surface != null and try hasSurfaceSupport(instance, pd, indices.graphics.?, surface.?)) {
                    indices.present = indices.graphics;
                }
            }

            if (family_props.queue_flags.compute_bit) {
                indices.compute = @intCast(u32, index);

                transfer_score +%= 1;
            }

            if (family_props.queue_flags.transfer_bit) {
                if (transfer_score <= min_transfer_score) {
                    min_transfer_score = transfer_score;
                    indices.transfer = @intCast(u32, index);
                }
            }
        }

        return indices;
    }

    pub fn format(
        families: QueueFamilyIndices,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("\n\tgraphics:\t {?}\n\tpresent:\t {?}\n\tcompute:\t {?}\n\ttransfer:\t {?}", .{
            families.graphics,
            families.present,
            families.compute,
            families.transfer,
        });
    }
};

pub fn selectPhysicalDevice(
    instance: VulkanInstance,
    requirements: vulkan_types.PhysicalDeviceRequirements,
    surface: vk.SurfaceKHR,
    allocator: Allocator,
) !vk.PhysicalDevice {
    var pd_count: u32 = 0;
    _ = try instance.vki.enumeratePhysicalDevices(instance.handle, &pd_count, null);

    const physical_devices = try allocator.alloc(vk.PhysicalDevice, pd_count);
    defer allocator.free(physical_devices);
    _ = try instance.vki.enumeratePhysicalDevices(instance.handle, &pd_count, physical_devices.ptr);

    var highest_suitability_rating: i32 = -1;
    var highest_suitabliity_rating_index: ?usize = null;

    for (physical_devices, 0..) |pd, index| {
        const info = vulkan_types.PhysicalDeviceInfo.get(instance, pd);

        log.debug("checking device {s}...", .{info.properties.device_name});

        // ensure required queue families are supported
        //
        const queue_families = try vulkan_types.QueueFamilyIndices.find(instance, pd, surface, allocator);

        if (requirements.queues.graphics and queue_families.graphics == null) {
            log.debug("missing graphics queue", .{});
            continue;
        }

        if (requirements.queues.present and queue_families.present == null) {
            log.debug("missing present queue", .{});
            continue;
        }

        if (requirements.queues.compute and queue_families.compute == null) {
            log.debug("missing compute queue", .{});
            continue;
        }

        if (requirements.queues.transfer and queue_families.transfer == null) {
            log.debug("missing transfer queue", .{});
            continue;
        }

        // ensure required extensions are supported
        //
        if (requirements.extensions.len > 1) {
            if (try areExtensionsSupported(instance, pd, requirements.extensions[0..], allocator) == false) {
                log.debug("missing required extension", .{});
                continue;
            }
        }

        // ensure surface support
        //
        const swapchain_support_info = try vulkan_types.SwapchainSupportInfo.initGet(
            allocator,
            instance,
            pd,
            surface,
        );
        defer swapchain_support_info.deinit(allocator);

        if (swapchain_support_info.surface_formats.len < 1 or swapchain_support_info.present_modes.len < 1) {
            log.info("no surface support", .{});
            continue;
        }

        // prefer dedicated graphics cards
        //
        const props = instance.vki.getPhysicalDeviceProperties(pd);

        const suitability_rating: i32 = switch (props.device_type) {
            .cpu => 0,
            .virtual_gpu => 2,
            .integrated_gpu => 3,
            .discrete_gpu => 4,
            else => -1, // other, unknown type
        };

        if (suitability_rating > highest_suitability_rating) {
            highest_suitability_rating = suitability_rating;
            highest_suitabliity_rating_index = index;
        }
    }

    if (highest_suitabliity_rating_index) |index| {
        return physical_devices[index];
    }

    return error.NoSuitableDevice;
}

/// Memory is owned and freed by function.
fn areExtensionsSupported(instance: VulkanInstance, pd: vk.PhysicalDevice, extensions: []const [*:0]const u8, allocator: Allocator) !bool {
    var ext_count: u32 = 0;
    _ = try instance.vki.enumerateDeviceExtensionProperties(pd, null, &ext_count, null);
    const pd_ext_props = try allocator.alloc(vk.ExtensionProperties, ext_count);
    defer allocator.free(pd_ext_props);
    _ = try instance.vki.enumerateDeviceExtensionProperties(pd, null, &ext_count, @ptrCast([*]vk.ExtensionProperties, pd_ext_props.ptr));

    // ensure extensions are in the physical device's list of supported extensions
    for (extensions) |required_ext_name| {
        for (pd_ext_props) |pd_ext| {
            const pd_ext_name = @ptrCast([*:0]const u8, &pd_ext.extension_name);

            if (std.mem.eql(u8, std.mem.span(required_ext_name), std.mem.span(pd_ext_name))) {
                break;
            }
        } else {
            return false;
        }
    }
    return true;
}
