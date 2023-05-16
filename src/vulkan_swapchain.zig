const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.vulkan_swapchain);
const vulkan_types = @import("vulkan_types.zig");
const vk = vulkan_types.vk;
const VulkanEntry = vulkan_types.VulkanEntry;
const VulkanInstance = vulkan_types.VulkanInstance;
const VulkanDevice = vulkan_types.VulkanDevice;
const VulkanContext = vulkan_types.VulkanContext;

const Window = @import("window.zig").Window;

const is_debug_build = builtin.mode == std.builtin.Mode.Debug;

/// The preference lists should be ordered from most desirable to least desirable.
const SwapchainInitParams = struct {
    window: Window,
    preferred_surface_formats: []const vk.SurfaceFormatKHR,
    preferred_present_modes: []const vk.PresentModeKHR,
};

pub const Swapchain = struct {
    handle: vk.SwapchainKHR,

    surface_format: vk.SurfaceFormatKHR,
    images: []vk.Image,
    image_views: []vk.ImageView,

    max_frames_in_flight: usize,

    pub fn deinit(swapchain: *Swapchain, context: VulkanContext) void {
        swapchain.destroyAndFreeImagesAndImageViews(context);
        context.device.destroySwapchainKHR(swapchain.handle, null);
    }

    pub fn init(context: VulkanContext, params: SwapchainInitParams) !Swapchain {
        const support = try vulkan_types.SwapchainSupportInfo.initGet(context.allocator, context.inst, context.physical_device, context.surface);
        defer support.deinit(context.allocator);

        const image_extent: vk.Extent2D = try findTrueWindowExtent(params.window, support.surface_capabilities);

        const surface_format = try findSuitableSurfaceFormat(support, params.preferred_surface_formats);
        const present_mode = try findSuitablePresentMode(support, params.preferred_present_modes);

        log.info("present mode {s}", .{@tagName(present_mode)});

        const image_count = blk: {
            const suggested_image_count = support.surface_capabilities.min_image_count + 1;
            const has_maximum_value = support.surface_capabilities.max_image_count > 0;

            break :blk switch (has_maximum_value) {
                true => std.math.min(suggested_image_count, support.surface_capabilities.max_image_count),
                false => suggested_image_count,
            };
        };
        const max_frames_in_flight = image_count - 1;

        if (context.queue_families.graphics == null or context.queue_families.present == null) {
            return error.SwapchainNeedsGraphicsAndPresentQueue;
        }

        const queue_family_indices = [2]u32{ context.queue_families.graphics.?, context.queue_families.present.? };
        const sharing_mode = vk.SharingMode.exclusive;

        const create_info = vk.SwapchainCreateInfoKHR{
            .flags = .{},
            .surface = context.surface,
            .min_image_count = image_count,
            .image_format = surface_format.format,
            .image_color_space = surface_format.color_space,
            .image_extent = image_extent,
            .image_array_layers = 1,
            .image_usage = .{ .color_attachment_bit = true, .transfer_dst_bit = true },
            .image_sharing_mode = sharing_mode,
            .queue_family_index_count = queue_family_indices.len,
            .p_queue_family_indices = &queue_family_indices,
            .pre_transform = support.surface_capabilities.current_transform,
            .composite_alpha = .{ .opaque_bit_khr = true },
            .present_mode = present_mode,
            .clipped = vk.TRUE,
            .old_swapchain = .null_handle,
        };

        const handle = try context.device.createSwapchainKHR(&create_info, null);

        // const depth_format = try findSuitableDepthFormat(context, params.preferred_depth_formats);

        var swapchain = Swapchain{
            .handle = handle,
            .surface_format = surface_format,
            .max_frames_in_flight = max_frames_in_flight,
            .images = &.{},
            .image_views = &.{},
        };

        try swapchain.reinitImages(context);

        return swapchain;
    }

    fn destroyAndFreeImagesAndImageViews(swapchain: *Swapchain, context: VulkanContext) void {
        for (swapchain.image_views) |image_view| context.device.destroyImageView(image_view, null);
        context.allocator.free(swapchain.image_views);
        context.allocator.free(swapchain.images);
    }

    fn reinitImages(swapchain: *Swapchain, context: VulkanContext) !void {
        var count: u32 = undefined;
        _ = try context.device.getSwapchainImagesKHR(swapchain.handle, &count, null);

        // reallocate if size is not the same as existing allocation
        if (count != swapchain.images.len) {
            swapchain.destroyAndFreeImagesAndImageViews(context);

            swapchain.images = try context.allocator.alloc(vk.Image, count);
            swapchain.image_views = try context.allocator.alloc(vk.ImageView, count);
        }

        errdefer swapchain.destroyAndFreeImagesAndImageViews(context);

        // get swapchain images
        _ = try context.device.getSwapchainImagesKHR(swapchain.handle, &count, swapchain.images.ptr);

        // create swapchain image views
        for (swapchain.images) |image, index| {
            swapchain.image_views[index] = try context.device.createImageView(&vk.ImageViewCreateInfo{
                .flags = .{},
                .image = image,
                .view_type = vk.ImageViewType.@"2d",
                .format = swapchain.surface_format.format,
                .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
                .subresource_range = vk.ImageSubresourceRange{
                    .aspect_mask = .{ .color_bit = true },
                    .base_mip_level = 0,
                    .level_count = 1,
                    .base_array_layer = 0,
                    .layer_count = 1,
                },
            }, null);
        }
    }
};

/// Present modes:
///
/// * FIFO => First-in, first-out queue. Blocks and waits for more images once the queue is full.
///     Similar to v-sync. Guaranteed to be available.
///
/// * Mailbox => Defaults to triple buffering. Like fifo but doesn't block when the queue is full.
///     Uses the latest image available and trashes the rest.
///
/// * Immediate => Double buffering. Fastest, but doesn't wait for vertical blank. Prone to screen-tearing.
///
fn findSuitablePresentMode(info: vulkan_types.SwapchainSupportInfo, preferred_present_modes: []const vk.PresentModeKHR) !vk.PresentModeKHR {
    for (preferred_present_modes) |preferred_mode| {
        if (std.mem.indexOfScalar(vk.PresentModeKHR, info.present_modes, preferred_mode) != null) {
            return preferred_mode;
        }
    }

    return .fifo_khr;
}

fn findSuitableSurfaceFormat(info: vulkan_types.SwapchainSupportInfo, preferred_formats: []const vk.SurfaceFormatKHR) !vk.SurfaceFormatKHR {
    // use first preferred format that exists, if one exists
    for (preferred_formats) |preferred_format| {
        for (info.surface_formats) |available_format| {
            if (std.meta.eql(available_format, preferred_format)) {
                return preferred_format;
            }
        }
    }

    // if none of the preferred formats exist, just use the first available format
    if (info.surface_formats.len < 1) {
        return error.FailedToFindSurfaceFormats;
    }

    return info.surface_formats[0];
}

/// The swapchain extent is the resolution of the swapchain images
fn findTrueWindowExtent(
    window: Window,
    surface_capabilities: vk.SurfaceCapabilitiesKHR,
) !vk.Extent2D {
    const current_extent = surface_capabilities.current_extent;

    if (current_extent.width != std.math.maxInt(u32)) {
        return current_extent;
    }
    // If current_extent is set to (0xffffff, 0xffffff), the window manager allows custom
    // resolutions and vulkan didn't set it automatically

    // Get the window extent from the window manager
    var width: i32 = undefined;
    var height: i32 = undefined;
    try window.getWindowSize(&width, &height);

    const min = surface_capabilities.min_image_extent;
    const max = surface_capabilities.max_image_extent;

    return vk.Extent2D{
        .width = std.math.clamp(@intCast(u32, width), min.width, max.width),
        .height = std.math.clamp(@intCast(u32, height), min.height, max.height),
    };
}
