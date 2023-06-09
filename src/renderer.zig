const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.renderer);
const vulkan_types = @import("vulkan_types.zig");
const vk = vulkan_types.vk;
const VulkanEntry = vulkan_types.VulkanEntry;
const VulkanInstance = vulkan_types.VulkanInstance;
const VulkanDevice = vulkan_types.VulkanDevice;
const Window = @import("window.zig").Window;
const Swapchain = vulkan_types.Swapchain;

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

    pub fn deinit(renderer: *Renderer) void {
        renderer.backend.deinit();
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

    pub fn deinit(backend: *RenderBackend) void {
        backend.context.deinit();
    }

    pub fn beginFrame(backend: *RenderBackend) !void {
        _ = backend;
    }

    pub fn endFrame(backend: *RenderBackend) !void {
        backend.debug_info.rendered_frames += 1;
    }
};

const vk_init = struct {
    const default_image_create_info = vk.ImageCreateInfo{
        // always fill out:
        // format
        // extent.width, extent.height
        // tiling
        // usage
        .flags = .{},
        .image_type = .@"2d",
        .format = undefined,
        .extent = vk.Extent3D{
            .width = undefined,
            .height = undefined,
            .depth = 1,
        },
        .mip_levels = 1,
        .array_layers = 1,
        .samples = .{ .@"1_bit" = true },
        .tiling = .optimal, //
        .usage = undefined,
        .sharing_mode = .exclusive,
        // these are only here for if sharing mode is concurrent
        .queue_family_index_count = undefined,
        .p_queue_family_indices = undefined,
        //
        .initial_layout = .undefined,
    };

    const ImageCreateInfoQuickParams = struct {
        usage: vk.ImageUsageFlags,
        format: vk.Format,
        width: u32,
        height: u32,
        depth: u32 = 1,
        tiling: vk.ImageTiling = .optimal, //
    };

    fn imageCreateInfo(params: ImageCreateInfoQuickParams) vk.ImageCreateInfo {
        var create_info = default_image_create_info;
        create_info.usage = params.usage;
        create_info.format = params.format;
        create_info.extent = vk.Extent3D{
            .width = params.width,
            .height = params.height,
            .depth = params.depth,
        };
        create_info.tiling = params.tiling;
        return create_info;
    }
};

pub const VulkanContext = struct {
    allocator: Allocator,

    entry: VulkanEntry,
    inst: VulkanInstance,
    debug_messenger: ?vk.DebugUtilsMessengerEXT,
    surface: vk.SurfaceKHR,
    physical_device: vk.PhysicalDevice,
    device: VulkanDevice,

    queue_families: vulkan_types.QueueFamilyIndices,
    queues: vulkan_types.Queues,

    swapchain: Swapchain,
    current_image_index: u32,
    current_frame: usize,

    const Image = struct {
        handle: vk.Image,
        memory: vk.DeviceMemory,
        height: u32,
        width: u32,
    };

    pub fn deinit(context: *VulkanContext) void {
        defer context.entry.deinit();
        defer context.inst.deinit();
        defer if (context.debug_messenger) |debug_messenger| context.inst.destroyDebugUtilsMessengerEXT(debug_messenger, null);
        defer context.inst.destroySurfaceKHR(context.surface, null);
        defer context.device.deinit();
        defer context.swapchain.deinit(context.*);
    }

    pub fn init(window: Window) !VulkanContext {
        const allocator = std.heap.page_allocator;

        var entry = try VulkanEntry.init();
        errdefer entry.deinit();

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

        // instance layers
        const required_instance_layers = switch (is_debug_build) {
            true => [_][*:0]const u8{ "VK_LAYER_KHRONOS_validation", "VK_LAYER_LUNARG_monitor" },
            false => [_][*:0]const u8{},
        };
        if (is_debug_build and try entry.areInstanceLayersSupported(required_instance_layers[0..], allocator) == false) {
            return error.MissingRequiredInstanceLayer;
        }

        const instance = try VulkanInstance.init(entry, required_instance_layers[0..], instance_extensions[0..]);
        errdefer instance.deinit();
        log.debug("Vulkan instance initialized with extensions: \t{s}", .{instance_extensions});

        const debug_messenger: ?vk.DebugUtilsMessengerEXT = switch (is_debug_build) {
            true => try @import("vulkan_debug_messenger.zig").initDebugMessenger(instance),
            false => null,
        };
        errdefer if (is_debug_build) instance.destroyDebugUtilsMessengerEXT(debug_messenger.?, null);

        const surface = try vulkan_types.surface.createSurface(instance, window);
        errdefer instance.destroySurfaceKHR(surface, null);

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

        const queue_families = try vulkan_types.QueueFamilyIndices.find(instance, physical_device, surface, allocator);
        log.info("queue families: {}", .{queue_families});

        const physical_device_info = vulkan_types.PhysicalDeviceInfo.get(instance, physical_device);
        log.info("physical device info: {}", .{physical_device_info});

        const device = try vulkan_types.VulkanDevice.init(instance, physical_device, queue_families, device_extensions[0..]);
        errdefer device.deinit();

        const queues = vulkan_types.Queues.get(device, queue_families);

        var context = VulkanContext{
            .allocator = allocator,
            //
            .entry = entry,
            .inst = instance,
            .debug_messenger = debug_messenger,
            .surface = surface,
            .physical_device = physical_device,
            .device = device,
            .queue_families = queue_families,
            .queues = queues,

            .swapchain = undefined,

            .current_image_index = 0,
            .current_frame = 0,
        };

        context.swapchain = try Swapchain.init(context, .{
            .window = window,
            .preferred_surface_formats = &.{.{
                .format = .b8g8r8a8_srgb, // RGBA SRGB
                .color_space = .srgb_nonlinear_khr, // nonlinear color space
            }},
            .preferred_present_modes = &.{.mailbox_khr},
        });

        const preferred_depth_formats: []const vk.Format = &.{
            .d32_sfloat,
            .d32_sfloat_s8_uint,
            .d24_unorm_s8_uint,
        };

        var tiling: vk.ImageTiling = undefined;

        const depth_format = blk: {
            const required_flags: vk.FormatFeatureFlags = .{ .depth_stencil_attachment_bit = true };

            for (preferred_depth_formats) |format| {
                const format_props: vk.FormatProperties = context.inst.getPhysicalDeviceFormatProperties(context.physical_device, format);

                if (format_props.linear_tiling_features.contains(required_flags)) {
                    tiling = vk.ImageTiling.linear;
                    break :blk format;
                }

                if (format_props.optimal_tiling_features.contains(required_flags)) {
                    tiling = vk.ImageTiling.optimal;
                    break :blk format;
                }
            }

            return error.FailedToFindDepthFormat;
        };

        _ = depth_format;

        return context;

        // create depth image
        // const depth_image_create_info = vk_init.imageCreateInfo(ImageCreateInfoQuickParams{
        //     .usage = vk.ImageUsageFlags{ .depth_stencil_attachment_bit = true },
        //     .format = swapchain.depth_format,
        //     .width: u32,
        //     .height: u32,
        //     .depth: u32 = 1,
        //     .tiling: vk.ImageTiling = .optimal, //

        //     };

        // const depth_format = findSuitableDepthFormat(context, &.{
        //     // NOTE: This order should change if using a stencil component is desired
        //     .d32_sfloat,
        //     .d32_sfloat_s8_uint,
        //     .d24_unorm_s8_uint,
        // });

        // TODO; Should the depth image even be here? Or is it better placed directly on the context?
        // depth_format: vk.Format,
        // depth_image: vk.Image,
        // depth_image_view: vk.ImageView,

    }
};

fn findSuitableDepthFormat(context: VulkanContext, preferred_formats: []const vk.Format) !vk.Format {
    const required_flags: vk.FormatFeatureFlags = .{ .depth_stencil_attachment_bit = true };

    for (preferred_formats) |format| {
        const format_props: vk.FormatProperties = context.inst.getPhysicalDeviceFormatProperties(context.physical_device, format);

        if (format_props.linear_tiling_features.contains(required_flags)) {
            return format;
        }

        if (format_props.optimal_tiling_features.contains(required_flags)) {
            return format;
        }
    }

    return error.FailedToFindDepthFormat;
}
