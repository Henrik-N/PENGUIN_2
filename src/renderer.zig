const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.renderer);
const vulkan_types = @import("vulkan_types.zig");
const vk = vulkan_types.vk;
const VulkanEntry = vulkan_types.VulkanEntry;
const VulkanInstance = vulkan_types.VulkanInstance;

const Window = @import("window.zig").Window;

const is_debug_build = builtin.mode == std.builtin.Mode.Debug;

pub const RenderPacket = struct {
    delta_time: f32,
};

pub const Renderer = struct {
    backend: RenderBackend,

    pub fn init(window: Window) !Renderer {
        const backend = RenderBackend.init(window) catch |e| {
            log.err("render backend failed to init.", .{});
            return e;
        };

        return Renderer{
            .backend = backend,
        };
    }

    pub fn deinit(renderer: Renderer) void {
        _ = renderer;
    }

    pub fn onWindowResize(renderer: Renderer) void {
        _ = renderer;
    }

    pub fn renderFrame(renderer: *Renderer, packet: RenderPacket) !void {
        const backend: *RenderBackend = &renderer.backend;

        try backend.beginFrame();

        _ = packet;

        try backend.endFrame();
    }
};

const RenderBackend = struct {
    window: *const Window,
    debug_info: struct {
        rendered_frames: u64 = 0,
    },

    context: VulkanContext,

    pub fn init(window: Window) !RenderBackend {
        return RenderBackend{
            .window = &window,
            .debug_info = .{},
            .context = try VulkanContext.init(window),
        };
    }

    pub fn beginFrame(backend: *RenderBackend) !void {
        _ = backend;
    }

    pub fn endFrame(backend: *RenderBackend) !void {
        backend.debug_info.rendered_frames += 1;
    }
};

pub const VulkanContext = struct {
    pub fn init(window: Window) !VulkanContext {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        var entry = try VulkanEntry.init();
        defer entry.deinit();

        // instance layers
        const required_instance_layers = switch (is_debug_build) {
            true => [_][*:0]const u8{ "VK_LAYER_KHRONOS_validation", "VK_LAYER_LUNARG_monitor" },
            false => [_][*:0]const u8{},
        };
        if (is_debug_build and try entry.areInstanceLayersSupported(required_instance_layers[0..], allocator) == false) {
            return error.MissingRequiredInstanceLayer;
        }

        // instance extensions
        const instance_extensions = blk: {
            const platform_surface_extension_name = switch (builtin.os.tag) {
                .linux => vk.extension_info.khr_xcb_surface.name,
                .windows => vk.extension_info.khr_win_32_surface.name,
                else => @compileError("no surface extension specified for this platform (" ++ @tagName(builtin.os.tag) ++ ")"),
            };

            const surface_extensions = [_][*:0]const u8{
                vk.extension_info.khr_surface.name,
                platform_surface_extension_name,
            };

            const debug_extensions = switch (is_debug_build) {
                true => [_][*:0]const u8{vk.extension_info.ext_debug_utils.name},
                false => [_][*:0]const u8{},
            };

            break :blk surface_extensions ++ debug_extensions;
        };

        const instance = try VulkanInstance.init(entry, required_instance_layers[0..], instance_extensions[0..]);
        defer instance.deinit();
        log.debug("Vulkan instance initialized with extensions: \t{s}", .{instance_extensions});

        const debug_messenger: ?vk.DebugUtilsMessengerEXT = switch (is_debug_build) {
            true => try @import("vulkan_debug_messenger.zig").initDebugMessenger(instance),
            false => null,
        };
        defer if (is_debug_build) instance.vki.destroyDebugUtilsMessengerEXT(instance.handle, debug_messenger.?, null);

        const surface = try vulkan_types.surface.createSurface(instance, window);
        defer instance.vki.destroySurfaceKHR(instance.handle, surface, null);

        // physical device selection
        const device_extensions = [_][*:0]const u8{vk.extension_info.khr_swapchain.name};
        const physical_device = try vulkan_types.physical_device.selectPhysicalDevice(
            instance,
            vulkan_types.PhysicalDeviceRequirements{
                .queues = .{
                    .graphics = true,
                    .present = true,
                },
                .extensions = device_extensions[0..],
            },
            surface,
            allocator,
        );

        const swapchain_support_info = try vulkan_types.SwapchainSupportInfo.initGet(allocator, instance, physical_device, surface);
        defer swapchain_support_info.deinit(allocator);

        const queue_families = try vulkan_types.QueueFamilyIndices.find(instance, physical_device, surface, allocator);
        log.info("queue families: {}", .{queue_families});

        const physical_device_info = vulkan_types.PhysicalDeviceInfo.get(instance, physical_device);
        logPhysicalDeviceInfo(physical_device_info);

        return VulkanContext{};
    }
};

fn logPhysicalDeviceInfo(info: vulkan_types.PhysicalDeviceInfo) void {
    const props = info.properties;
    log.info("using: {s}", .{props.device_name});
    log.info("\t Vulkan version:\t {}.{}.{}", .{
        vk.apiVersionMajor(props.api_version),
        vk.apiVersionMinor(props.api_version),
        vk.apiVersionPatch(props.api_version),
    });
    log.info("\t Gpu driver version:\t {}.{}.{}", .{
        vk.apiVersionMajor(props.driver_version),
        vk.apiVersionMinor(props.driver_version),
        vk.apiVersionPatch(props.driver_version),
    });

    const memory_heaps = info.memory.memory_heaps[0..info.memory.memory_heap_count];

    log.info("\t Memory heaps:", .{});

    for (memory_heaps) |heap_info, index| {
        const megabytes = @intToFloat(f32, heap_info.size) / 1024.0 / 1024.0;

        if (heap_info.flags.contains(vk.MemoryHeapFlags{ .device_local_bit = true })) {
            log.info("\t\t {}: device local \t{d:.2} MB", .{ index, megabytes });
        } else {
            log.info("\t\t {}: system shared \t{d:.2} MB", .{ index, megabytes });
        }
    }
}
