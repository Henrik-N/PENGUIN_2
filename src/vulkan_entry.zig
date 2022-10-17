const std = @import("std");
const builtin = @import("builtin");
const log = std.log.scoped(.vulkan_entry);
const Allocator = std.mem.Allocator;
const vk = @import("vulkan_types.zig").vk;

const BaseDispatch = vk.BaseWrapper(.{
    .createInstance = true,
    .getInstanceProcAddr = true,
    .enumerateInstanceVersion = true,
    .enumerateInstanceLayerProperties = true,
    .enumerateInstanceExtensionProperties = true,
});

/// Entry point for the Vulkan library.
pub const VulkanEntry = struct {
    dl: std.DynLib,
    vkb: BaseDispatch,
    loader_fn: vk.PfnGetInstanceProcAddr,

    pub fn deinit(entry: *VulkanEntry) void {
        entry.dl.close();
    }

    pub fn init() !VulkanEntry {
        var vk_dl = try openVulkanDynLib();
        errdefer vk_dl.close();

        // load instance loading function from dl
        const loader_fn: vk.PfnGetInstanceProcAddr = vk_dl.lookup(vk.PfnGetInstanceProcAddr, "vkGetInstanceProcAddr") orelse {
            log.err("failed to get instance proc address", .{});
            return error.FailedToGetInstanceProcAddr;
        };

        const vkb = BaseDispatch.load(loader_fn) catch |e| {
            log.err("Base dispatch load failure {}", .{e});
            return e;
        };

        return VulkanEntry{
            .dl = vk_dl,
            .vkb = vkb,
            .loader_fn = loader_fn,
        };
    }

    pub fn areInstanceLayersSupported(entry: VulkanEntry, required_layer_names: []const [*:0]const u8, allocator: Allocator) !bool {
        var count: u32 = 0;
        _ = try entry.vkb.enumerateInstanceLayerProperties(&count, null);

        const layers = try allocator.alloc(vk.LayerProperties, count);
        defer allocator.free(layers);
        _ = try entry.vkb.enumerateInstanceLayerProperties(&count, layers.ptr);

        var matches: usize = 0;
        for (required_layer_names) |required_layer_name| {
            for (layers) |available_layer| {
                const available_layer_slice: []const u8 = std.mem.span(@ptrCast([*:0]const u8, &available_layer.layer_name));
                const required_layer_slice: []const u8 = std.mem.span(@ptrCast([*:0]const u8, required_layer_name));

                if (std.mem.eql(u8, available_layer_slice, required_layer_slice)) {
                    matches += 1;
                    break;
                }
            }
        }

        if (matches != required_layer_names.len) {
            return false;
        }
        return true;
    }
};

fn openVulkanDynLib() !std.DynLib {
    const lib_path: [:0]const u8 = switch (builtin.os.tag) {
        .linux => "libvulkan.so.1",
        .windows => "vulkan-1.dll",
        .macos => "libvulkan.dylib",
        else => @compileError("no vulkan lib path for this platform specified"),
    };
    var vk_dl = std.DynLib.open(lib_path) catch |e| {
        log.err("failed to open vulkan dl: {}", .{e});
        return e;
    };
    errdefer vk_dl.close();

    return vk_dl;
}
