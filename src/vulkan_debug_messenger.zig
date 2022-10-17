const vulkan_types = @import("vulkan_types.zig");
const vk = vulkan_types.vk;
const VulkanInstance = vulkan_types.VulkanInstance;
const vk_log = @import("std").log.scoped(.vk_debug);

pub fn initDebugMessenger(instance: VulkanInstance) !vk.DebugUtilsMessengerEXT {
    return try instance.vki.createDebugUtilsMessengerEXT(instance.handle, &.{
        .flags = .{},
        .message_severity = .{
            // .verbose_bit_ext = true,
            .info_bit_ext = true,
            .warning_bit_ext = true,
            .error_bit_ext = true,
        },
        .message_type = .{
            // .general_bit_ext = true,
            .validation_bit_ext = true,
            .performance_bit_ext = true,
        },
        .pfn_user_callback = debugMessengerCallback,
        .p_user_data = null,
    }, null);
}

fn debugMessengerCallback(
    message_severity: vk.DebugUtilsMessageSeverityFlagsEXT,
    message_type: vk.DebugUtilsMessageTypeFlagsEXT,
    p_callback_data: ?*const vk.DebugUtilsMessengerCallbackDataEXT,
    p_user_data: ?*anyopaque,
) callconv(vk.vulkan_call_conv) vk.Bool32 {
    _ = p_user_data;

    const scope = struct {
        fn prefix(msg_type: vk.DebugUtilsMessageTypeFlagsEXT) []const u8 {
            if (msg_type.contains(.{ .general_bit_ext = true })) {
                return "(general) ";
            } else if (msg_type.contains(.{ .validation_bit_ext = true })) {
                return "(validation) ";
            } else if (msg_type.contains(.{ .performance_bit_ext = true })) {
                return "(performance) ";
            }

            return "(unknown) ";
        }
    };

    if (p_callback_data) |callback_data| {
        const msg = callback_data.p_message;

        if (message_severity.contains(.{ .info_bit_ext = true })) {
            vk_log.info("{s}{s}", .{ scope.prefix(message_type), msg });
        } else if (message_severity.contains(.{ .warning_bit_ext = true })) {
            vk_log.warn("{s}{s}", .{ scope.prefix(message_type), msg });
        } else if (message_severity.contains(.{ .error_bit_ext = true })) {
            vk_log.err("{s}{s}", .{ scope.prefix(message_type), msg });
        } else {
            vk_log.err("(Unknown severity) {s}{s}\n", .{ scope.prefix(message_type), callback_data.p_message });
        }
    }

    return vk.FALSE;
}
