const std = @import("std");
const builtin = @import("builtin");
const log = std.log.scoped(.vulkan_logical_device);
const vulkan_types = @import("vulkan_types.zig");
const vk = vulkan_types.vk;
const VulkanInstance = vulkan_types.VulkanInstance;
const QueueFamilyIndices = vulkan_types.QueueFamilyIndices;

const DeviceDispatch = vk.DeviceWrapper(.{
    .destroyDevice = true,
    .getDeviceQueue = true,
});

pub const Queues = struct {
    graphics: vk.Queue,
    present: vk.Queue,
    compute: vk.Queue,
    transfer: vk.Queue,

    pub fn get(device: VulkanDevice, queue_families: QueueFamilyIndices) Queues {
        // getting the first queue in the family
        const queue_index = 0;

        return Queues{
            .graphics = if (queue_families.graphics) |queue| device.vkd.getDeviceQueue(device.handle, queue, queue_index) else vk.Queue.null_handle,
            .present = if (queue_families.present) |queue| device.vkd.getDeviceQueue(device.handle, queue, queue_index) else .null_handle,
            .compute = if (queue_families.compute) |queue| device.vkd.getDeviceQueue(device.handle, queue, queue_index) else .null_handle,
            .transfer = if (queue_families.transfer) |queue| device.vkd.getDeviceQueue(device.handle, queue, queue_index) else .null_handle,
        };
    }
};

pub const VulkanDevice = struct {
    handle: vk.Device,
    vkd: DeviceDispatch,

    pub fn deinit(device: VulkanDevice) void {
        device.vkd.destroyDevice(device.handle, null);
    }

    pub fn init(
        instance: VulkanInstance,
        physical_device: vk.PhysicalDevice,
        queue_families: QueueFamilyIndices,
        extensions: []const [*:0]const u8,
    ) !VulkanDevice {
        const max_unique_family_indices = 4;
        std.debug.assert(@sizeOf(QueueFamilyIndices) / max_unique_family_indices == @sizeOf(?u32));

        const inline_allocation_size =
            @sizeOf(u32) * max_unique_family_indices +
            @sizeOf(vk.DeviceQueueCreateInfo) * max_unique_family_indices;

        var buffer: [inline_allocation_size]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buffer);
        const inline_allocator = fba.allocator();

        var unique_family_indices = try std.ArrayList(u32).initCapacity(inline_allocator, max_unique_family_indices);
        // defer unique_family_indices.deinit(); (unnecessary when inline)
        {
            if (queue_families.graphics != null) {
                unique_family_indices.appendAssumeCapacity(queue_families.graphics.?);
            }

            if (queue_families.present != null and queue_families.present != queue_families.graphics) {
                unique_family_indices.appendAssumeCapacity(queue_families.present.?);
            }

            if (queue_families.compute != null and queue_families.compute != queue_families.graphics) {
                unique_family_indices.appendAssumeCapacity(queue_families.compute.?);
            }

            if (queue_families.transfer != null and queue_families.transfer != queue_families.graphics) {
                unique_family_indices.appendAssumeCapacity(queue_families.transfer.?);
            }
        }

        var queue_create_infos = try std.ArrayList(vk.DeviceQueueCreateInfo).initCapacity(
            inline_allocator,
            max_unique_family_indices,
        );
        // defer queue_create_infos.deinit();

        const queue_priorities = [_]f32{1.0};

        for (unique_family_indices.items) |unique_family_index| {
            const create_info = vk.DeviceQueueCreateInfo{
                .flags = .{},
                .queue_family_index = unique_family_index,
                .queue_count = 1,
                .p_queue_priorities = &queue_priorities,
            };
            queue_create_infos.appendAssumeCapacity(create_info);
        }

        const features = vk.PhysicalDeviceFeatures{}; // TODO: ensure supported

        const create_info = vk.DeviceCreateInfo{
            .flags = .{},
            .queue_create_info_count = @intCast(u32, queue_create_infos.items.len),
            .p_queue_create_infos = queue_create_infos.items.ptr,
            .enabled_layer_count = 0, // deprecated (ignored)
            .pp_enabled_layer_names = undefined, // deprecated (ignored)
            .enabled_extension_count = @intCast(u32, extensions.len),
            .pp_enabled_extension_names = extensions.ptr,
            .p_enabled_features = &features,
        };

        const device = try instance.vki.createDevice(physical_device, &create_info, null);
        const vkd = try DeviceDispatch.load(device, instance.vki.dispatch.vkGetDeviceProcAddr);
        // errdefer vkd.destroyDevice(device, null);

        return VulkanDevice{
            .handle = device,
            .vkd = vkd,
        };
    }
};
