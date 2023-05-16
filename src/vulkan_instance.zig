const std = @import("std");
const builtin = @import("builtin");
const log = std.log.scoped(.vulkan_instance);
const vulkan_types = @import("vulkan_types.zig");
const vk = vulkan_types.vk;
const VulkanEntry = vulkan_types.VulkanEntry;

const is_debug_build = builtin.mode == std.builtin.Mode.Debug;

pub const VulkanInstance = struct {
    handle: vk.Instance,
    vki: InstanceDispatch,

    pub usingnamespace impl;
    pub usingnamespace reimpl;

    pub fn deinit(instance: VulkanInstance) void {
        instance.destroyInstance(null);
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

// Uncomment functions to load from dll
const InstanceDispatch = vk.InstanceWrapper(.{
    .destroyInstance = true,
    .enumeratePhysicalDevices = true,
    .getDeviceProcAddr = true,
    .getPhysicalDeviceProperties = true,
    .getPhysicalDeviceQueueFamilyProperties = true,
    .getPhysicalDeviceMemoryProperties = true,
    .getPhysicalDeviceFeatures = true,
    .getPhysicalDeviceFormatProperties = true,
    // .getPhysicalDeviceImageFormatProperties = true,
    .createDevice = true,
    // .enumerateDeviceLayerProperties = true,
    .enumerateDeviceExtensionProperties = true,
    // .getPhysicalDeviceSparseImageFormatProperties = true,
    // .createAndroidSurfaceKHR = true,
    // .getPhysicalDeviceDisplayPropertiesKHR = true,
    // .getPhysicalDeviceDisplayPlanePropertiesKHR = true,
    // .getDisplayPlaneSupportedDisplaysKHR = true,
    // .getDisplayModePropertiesKHR = true,
    // .createDisplayModeKHR = true,
    // .getDisplayPlaneCapabilitiesKHR = true,
    // .createDisplayPlaneSurfaceKHR = true,
    .destroySurfaceKHR = true,
    .getPhysicalDeviceSurfaceSupportKHR = true,
    .getPhysicalDeviceSurfaceCapabilitiesKHR = true,
    .getPhysicalDeviceSurfaceFormatsKHR = true,
    .getPhysicalDeviceSurfacePresentModesKHR = true,
    // .createViSurfaceNN = true,
    // .createWaylandSurfaceKHR = true,
    // .getPhysicalDeviceWaylandPresentationSupportKHR = true,
    // .createWin32SurfaceKHR = true,
    // .getPhysicalDeviceWin32PresentationSupportKHR = true,
    // .createXlibSurfaceKHR = true,
    // .getPhysicalDeviceXlibPresentationSupportKHR = true,
    .createXcbSurfaceKHR = builtin.os.tag == .linux,
    // .getPhysicalDeviceXcbPresentationSupportKHR = true,
    // .createDirectFbSurfaceEXT = true,
    // .getPhysicalDeviceDirectFbPresentationSupportEXT = true,
    // .createImagePipeSurfaceFUCHSIA = true,
    // .createStreamDescriptorSurfaceGGP = true,
    // .createScreenSurfaceQNX = true,
    // .getPhysicalDeviceScreenPresentationSupportQNX = true,
    // .createDebugReportCallbackEXT = true,
    // .destroyDebugReportCallbackEXT = true,
    // .debugReportMessageEXT = true,
    // .getPhysicalDeviceExternalImageFormatPropertiesNV = true,
    // .getPhysicalDeviceFeatures2 = true,
    // .getPhysicalDeviceProperties2 = true,
    // .getPhysicalDeviceFormatProperties2 = true,
    // .getPhysicalDeviceImageFormatProperties2 = true,
    // .getPhysicalDeviceQueueFamilyProperties2 = true,
    // .getPhysicalDeviceMemoryProperties2 = true,
    // .getPhysicalDeviceSparseImageFormatProperties2 = true,
    // .getPhysicalDeviceExternalBufferProperties = true,
    // .getPhysicalDeviceExternalSemaphoreProperties = true,
    // .getPhysicalDeviceExternalFenceProperties = true,
    // .releaseDisplayEXT = true,
    // .acquireXlibDisplayEXT = true,
    // .getRandROutputDisplayEXT = true
    // .acquireWinrtDisplayNV = true,
    // .getWinrtDisplayNV = true,
    // .getPhysicalDeviceSurfaceCapabilities2EXT = true,
    // .enumeratePhysicalDeviceGroups = true,
    // .getPhysicalDevicePresentRectanglesKHR = true,
    // .createIosSurfaceMVK = true,
    // .createMacOsSurfaceMVK = true,
    // .createMetalSurfaceEXT = true,
    // .getPhysicalDeviceMultisamplePropertiesEXT = true,
    // .getPhysicalDeviceSurfaceCapabilities2KHR = true,
    // .getPhysicalDeviceSurfaceFormats2KHR = true,
    // .getPhysicalDeviceDisplayProperties2KHR = true,
    // .getPhysicalDeviceDisplayPlaneProperties2KHR = true,
    // .getDisplayModeProperties2KHR = true,
    // .getDisplayPlaneCapabilities2KHR = true,
    // .getPhysicalDeviceCalibrateableTimeDomainsEXT = true,
    .createDebugUtilsMessengerEXT = true,
    .destroyDebugUtilsMessengerEXT = true,
    // .submitDebugUtilsMessageEXT = true,
    // .getPhysicalDeviceCooperativeMatrixPropertiesNV = true,
    // .getPhysicalDeviceSurfacePresentModes2EXT = true,
    // .enumeratePhysicalDeviceQueueFamilyPerformanceQueryCountersKHR = true,
    // .getPhysicalDeviceQueueFamilyPerformanceQueryPassesKHR = true,
    // .createHeadlessSurfaceEXT = true,
    // .getPhysicalDeviceSupportedFramebufferMixedSamplesCombinationsNV = true,
    // .getPhysicalDeviceToolPropertiesEXT = true,
    // .getPhysicalDeviceFragmentShadingRatesKHR = true,
    // .getPhysicalDeviceVideoCapabilitiesKHR = true,
    // .getPhysicalDeviceVideoFormatPropertiesKHR = true,
});

// function implementations that differ from the vulkan spec
const reimpl = struct {
    const Self = VulkanInstance;

    pub fn getPhysicalDeviceSurfaceFormatsKHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        surface: vk.SurfaceKHR,
        allocator: std.mem.Allocator,
    ) InstanceDispatch.GetPhysicalDeviceSurfaceFormatsKHRError!std.ArrayList(vk.SurfaceFormatKHR) {
        var count: u32 = 0;
        _ = try self.vki.getPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &count, null);

        const surface_formats = try allocator.alloc(vk.SurfaceFormatKHR, count);
        errdefer allocator.free(surface_formats);
        _ = try self.vki.getPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &count, surface_formats.ptr);

        return std.ArrayList(vk.SurfaceFormatKHR).fromOwnedSlice(surface_formats);
    }

    pub inline fn getPhysicalDeviceSurfacePresentModesKHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        surface: vk.SurfaceKHR,
        allocator: std.mem.Allocator,
    ) InstanceDispatch.GetPhysicalDeviceSurfacePresentModesKHRError!std.ArrayList(vk.PresentModeKHR) {
        var count: u32 = 0;
        _ = try self.vki.getPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &count, null);

        const present_modes = try allocator.alloc(vk.PresentModeKHR, count);
        errdefer allocator.free(present_modes);
        _ = try self.vki.getPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &count, present_modes.ptr);

        return std.ArrayList(vk.PresentModeKHR).fromOwnedSlice(present_modes);
    }

    // count = 0;

    // _ = try instance.vki.getPhysicalDeviceSurfacePresentModesKHR(pd, surface, &count, null);
    // const present_modes = try allocator.alloc(vk.PresentModeKHR, count);
    // errdefer allocator.free(present_modes);
    // _ = try instance.vki.getPhysicalDeviceSurfacePresentModesKHR(pd, surface, &count, present_modes.ptr);

    // return SwapchainSupportInfo{
    //     .surface_capabilities = surface_capabilities,
    //     .surface_formats = surface_formats,
    //     .present_modes = present_modes,
    // };

    // return self.vki.getPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, p_surface_format_count, p_surface_formats);

};

const impl = struct {
    const Self = VulkanInstance;

    pub inline fn destroyInstance(
        inst: Self,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) void {
        return inst.vki.destroyInstance(inst.handle, p_allocator);
    }

    pub inline fn enumeratePhysicalDevices(
        inst: Self,
        p_physical_device_count: *u32,
        p_physical_devices: ?[*]vk.PhysicalDevice,
    ) InstanceDispatch.EnumeratePhysicalDevicesError!vk.Result {
        return inst.vki.enumeratePhysicalDevices(inst.handle, p_physical_device_count, p_physical_devices);
    }

    pub inline fn getDeviceProcAddr(
        inst: Self,
        device: vk.Device,
        p_name: [*:0]const u8,
    ) vk.PfnVoidFunction {
        return inst.vki.getDeviceProcAddr(inst.handle, device, p_name);
    }

    pub inline fn getPhysicalDeviceProperties(
        inst: Self,
        physical_device: vk.PhysicalDevice,
    ) vk.PhysicalDeviceProperties {
        return inst.vki.getPhysicalDeviceProperties(inst.handle, physical_device);
    }

    pub inline fn getPhysicalDeviceQueueFamilyProperties(
        inst: VulkanInstance,
        physical_device: vk.PhysicalDevice,
        p_queue_family_property_count: *u32,
        p_queue_family_properties: ?[*]vk.QueueFamilyProperties,
    ) void {
        return inst.getPhysicalDeviceQueueFamilyProperties(inst.handle, physical_device, p_queue_family_property_count, p_queue_family_properties);
    }

    pub inline fn getPhysicalDeviceMemoryProperties(
        inst: VulkanInstance,
        physical_device: vk.PhysicalDevice,
    ) vk.PhysicalDeviceMemoryProperties {
        return inst.getPhysicalDeviceMemoryProperties(inst.handle, physical_device);
    }

    pub inline fn getPhysicalDeviceFeatures(
        self: Self,
        physical_device: vk.PhysicalDevice,
    ) vk.PhysicalDeviceFeatures {
        return self.vki.getPhysicalDeviceFeatures(self.handle, physical_device);
    }

    pub inline fn getPhysicalDeviceFormatProperties(
        self: Self,
        physical_device: vk.PhysicalDevice,
        format: vk.Format,
    ) vk.FormatProperties {
        return self.vki.getPhysicalDeviceFormatProperties(physical_device, format);
    }

    pub inline fn getPhysicalDeviceImageFormatProperties(
        self: Self,
        physical_device: vk.PhysicalDevice,
        format: vk.Format,
        @"type": vk.ImageType,
        tiling: vk.ImageTiling,
        usage: vk.ImageUsageFlags,
        flags: vk.ImageCreateFlags,
    ) InstanceDispatch.GetPhysicalDeviceImageFormatPropertiesError!vk.ImageFormatProperties {
        return self.vki.getPhysicalDeviceImageFormatProperties(physical_device, format, @"type", tiling, usage, flags);
    }

    pub inline fn createDevice(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_create_info: *const vk.DeviceCreateInfo,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) InstanceDispatch.CreateDeviceError!vk.Device {
        return self.vki.createDevice(physical_device, p_create_info, p_allocator);
    }

    pub inline fn enumerateDeviceLayerProperties(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_property_count: *u32,
        p_properties: ?[*]vk.LayerProperties,
    ) InstanceDispatch.EnumerateDeviceLayerPropertiesError!vk.Result {
        return self.vki.enumerateDeviceLayerProperties(physical_device, p_property_count, p_properties);
    }

    pub inline fn enumerateDeviceExtensionProperties(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_layer_name: ?[*:0]const u8,
        p_property_count: *u32,
        p_properties: ?[*]vk.ExtensionProperties,
    ) InstanceDispatch.EnumerateDeviceExtensionPropertiesError!vk.Result {
        return self.vki.enumerateDeviceExtensionProperties(physical_device, p_layer_name, p_property_count, p_properties);
    }

    pub inline fn getPhysicalDeviceSparseImageFormatProperties(
        self: Self,
        physical_device: vk.PhysicalDevice,
        format: vk.Format,
        @"type": vk.ImageType,
        samples: vk.SampleCountFlags,
        usage: vk.ImageUsageFlags,
        tiling: vk.ImageTiling,
        p_property_count: *u32,
        p_properties: ?[*]vk.SparseImageFormatProperties,
    ) void {
        return self.vki.getPhysicalDeviceSparseImageFormatProperties(physical_device, format, @"type", samples, usage, tiling, p_property_count, p_properties);
    }

    pub inline fn createAndroidSurfaceKHR(
        self: Self,
        p_create_info: *const vk.AndroidSurfaceCreateInfoKHR,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) InstanceDispatch.CreateAndroidSurfaceKHRError!vk.SurfaceKHR {
        return self.vki.createAndroidSurfaceKHR(self.handle, p_create_info, p_allocator);
    }

    pub inline fn getPhysicalDeviceDisplayPropertiesKHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_property_count: *u32,
        p_properties: ?[*]vk.DisplayPropertiesKHR,
    ) InstanceDispatch.GetPhysicalDeviceDisplayPropertiesKHRError!vk.Result {
        return self.vki.getPhysicalDeviceDisplayPropertiesKHR(physical_device, p_property_count, p_properties);
    }

    pub inline fn getPhysicalDeviceDisplayPlanePropertiesKHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_property_count: *u32,
        p_properties: ?[*]vk.DisplayPlanePropertiesKHR,
    ) InstanceDispatch.GetPhysicalDeviceDisplayPlanePropertiesKHRError!vk.Result {
        return self.vki.getPhysicalDeviceDisplayPlanePropertiesKHR(physical_device, p_property_count, p_properties);
    }

    pub inline fn getDisplayPlaneSupportedDisplaysKHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        plane_index: u32,
        p_display_count: *u32,
        p_displays: ?[*]vk.DisplayKHR,
    ) InstanceDispatch.GetDisplayPlaneSupportedDisplaysKHRError!vk.Result {
        return self.vki.getDisplayPlaneSupportedDisplaysKHR(physical_device, plane_index, p_display_count, p_displays);
    }

    pub inline fn getDisplayModePropertiesKHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        display: vk.DisplayKHR,
        p_property_count: *u32,
        p_properties: ?[*]vk.DisplayModePropertiesKHR,
    ) InstanceDispatch.GetDisplayModePropertiesKHRError!vk.Result {
        return self.vki.getDisplayModePropertiesKHR(physical_device, display, p_property_count, p_properties);
    }

    pub inline fn createDisplayModeKHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        display: vk.DisplayKHR,
        p_create_info: *const vk.DisplayModeCreateInfoKHR,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) InstanceDispatch.CreateDisplayModeKHRError!vk.DisplayModeKHR {
        return self.createDisplayModeKHR(physical_device, display, p_create_info, p_allocator);
    }

    pub inline fn getDisplayPlaneCapabilitiesKHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        mode: vk.DisplayModeKHR,
        plane_index: u32,
    ) InstanceDispatch.GetDisplayPlaneCapabilitiesKHRError!vk.DisplayPlaneCapabilitiesKHR {
        return self.vki.getDisplayPlaneCapabilitiesKHR(physical_device, mode, plane_index);
    }

    pub inline fn createDisplayPlaneSurfaceKHR(
        self: Self,
        p_create_info: *const vk.DisplaySurfaceCreateInfoKHR,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) InstanceDispatch.CreateDisplayPlaneSurfaceKHRError!vk.SurfaceKHR {
        return self.vki.createDisplayPlaneSurfaceKHR(self.handle, p_create_info, p_allocator);
    }

    pub inline fn destroySurfaceKHR(
        self: Self,
        surface: vk.SurfaceKHR,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) void {
        return self.vki.destroySurfaceKHR(self.handle, surface, p_allocator);
    }

    pub inline fn getPhysicalDeviceSurfaceSupportKHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        queue_family_index: u32,
        surface: vk.SurfaceKHR,
    ) InstanceDispatch.GetPhysicalDeviceSurfaceSupportKHRError!vk.Bool32 {
        return self.vki.getPhysicalDeviceSurfaceSupportKHR(physical_device, queue_family_index, surface);
    }

    pub inline fn getPhysicalDeviceSurfaceCapabilitiesKHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        surface: vk.SurfaceKHR,
    ) InstanceDispatch.GetPhysicalDeviceSurfaceCapabilitiesKHRError!vk.SurfaceCapabilitiesKHR {
        return self.getPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface);
    }

    // pub inline fn getPhysicalDeviceSurfaceFormatsKHR(
    //     self: Self,
    //     physical_device: vk.PhysicalDevice,
    //     surface: vk.SurfaceKHR,
    //     p_surface_format_count: *u32,
    //     p_surface_formats: ?[*]vk.SurfaceFormatKHR,
    // ) InstanceDispatch.GetPhysicalDeviceSurfaceFormatsKHRError!vk.Result {
    //     return self.vki.getPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, p_surface_format_count, p_surface_formats);
    // }

    // pub inline fn getPhysicalDeviceSurfacePresentModesKHR(
    //     self: Self,
    //     physical_device: vk.PhysicalDevice,
    //     surface: vk.SurfaceKHR,
    //     p_present_mode_count: *u32,
    //     p_present_modes: ?[*]vk.PresentModeKHR,
    // ) InstanceDispatch.GetPhysicalDeviceSurfacePresentModesKHRError!vk.Result {
    //     return self.vki.getPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, p_present_mode_count, p_present_modes);
    // }

    pub inline fn createViSurfaceNN(
        self: Self,
        p_create_info: *const vk.ViSurfaceCreateInfoNN,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) InstanceDispatch.CreateViSurfaceNNError!vk.SurfaceKHR {
        return self.vki.createViSurfaceNN(self.handle, p_create_info, p_allocator);
    }

    pub inline fn createWaylandSurfaceKHR(
        self: Self,
        p_create_info: *const vk.WaylandSurfaceCreateInfoKHR,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) InstanceDispatch.CreateWaylandSurfaceKHRError!vk.SurfaceKHR {
        return self.vki.createWaylandSurfaceKHR(self.handle, p_create_info, p_allocator);
    }

    pub inline fn getPhysicalDeviceWaylandPresentationSupportKHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        queue_family_index: u32,
        display: *vk.wl_display,
    ) vk.Bool32 {
        return self.vki.getPhysicalDeviceWaylandPresentationSupportKHR(physical_device, queue_family_index, display);
    }

    pub inline fn createWin32SurfaceKHR(
        self: Self,
        p_create_info: *const vk.Win32SurfaceCreateInfoKHR,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) InstanceDispatch.CreateWin32SurfaceKHRError!vk.SurfaceKHR {
        return self.vki.createWin32SurfaceKHR(self.handle, p_create_info, p_allocator);
    }

    pub inline fn getPhysicalDeviceWin32PresentationSupportKHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        queue_family_index: u32,
    ) vk.Bool32 {
        return self.vki.getPhysicalDeviceWin32PresentationSupportKHR(physical_device, queue_family_index);
    }

    pub inline fn createXlibSurfaceKHR(
        self: Self,
        p_create_info: *const vk.XlibSurfaceCreateInfoKHR,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) InstanceDispatch.CreateXlibSurfaceKHRError!vk.SurfaceKHR {
        return self.vki.createXlibSurfaceKHR(self.handle, p_create_info, p_allocator);
    }

    pub inline fn getPhysicalDeviceXlibPresentationSupportKHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        queue_family_index: u32,
        dpy: *vk.Display,
        visual_id: vk.VisualID,
    ) vk.Bool32 {
        return self.vki.getPhysicalDeviceXlibPresentationSupportKHR(physical_device, queue_family_index, dpy, visual_id);
    }

    pub inline fn createXcbSurfaceKHR(
        self: Self,
        p_create_info: *const vk.XcbSurfaceCreateInfoKHR,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) InstanceDispatch.CreateXcbSurfaceKHRError!vk.SurfaceKHR {
        return self.vki.createXcbSurfaceKHR(self.handle, p_create_info, p_allocator);
    }

    pub inline fn getPhysicalDeviceXcbPresentationSupportKHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        queue_family_index: u32,
        connection: *vk.xcb_connection_t,
        visual_id: vk.xcb_visualid_t,
    ) vk.Bool32 {
        return self.vki.getPhysicalDeviceXcbPresentationSupportKHR(physical_device, queue_family_index, connection, visual_id);
    }

    pub inline fn createDirectFbSurfaceEXT(
        self: Self,
        p_create_info: *const vk.DirectFBSurfaceCreateInfoEXT,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) InstanceDispatch.CreateDirectFbSurfaceEXTError!vk.SurfaceKHR {
        return self.vki.createDirectFbSurfaceEXT(self.handle, p_create_info, p_allocator);
    }

    pub inline fn getPhysicalDeviceDirectFbPresentationSupportEXT(
        self: Self,
        physical_device: vk.PhysicalDevice,
        queue_family_index: u32,
        dfb: *vk.IDirectFB,
    ) vk.Bool32 {
        return self.vki.getPhysicalDeviceDirectFbPresentationSupportEXT(physical_device, queue_family_index, dfb);
    }

    pub inline fn createImagePipeSurfaceFUCHSIA(
        self: Self,
        p_create_info: *const vk.ImagePipeSurfaceCreateInfoFUCHSIA,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) InstanceDispatch.CreateImagePipeSurfaceFUCHSIAError!vk.SurfaceKHR {
        return self.vki.createImagePipeSurfaceFUCHSIA(self.handle, p_create_info, p_allocator);
    }

    pub inline fn createStreamDescriptorSurfaceGGP(
        self: Self,
        p_create_info: *const vk.StreamDescriptorSurfaceCreateInfoGGP,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) InstanceDispatch.CreateStreamDescriptorSurfaceGGPError!vk.SurfaceKHR {
        return self.vki.createStreamDescriptorSurfaceGGP(self.handle, p_create_info, p_allocator);
    }

    pub inline fn createScreenSurfaceQNX(
        self: Self,
        p_create_info: *const vk.ScreenSurfaceCreateInfoQNX,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) InstanceDispatch.CreateScreenSurfaceQNXError!vk.SurfaceKHR {
        return self.vki.createScreenSurfaceQNX(self.handle, p_create_info, p_allocator);
    }

    pub inline fn getPhysicalDeviceScreenPresentationSupportQNX(
        self: Self,
        physical_device: vk.PhysicalDevice,
        queue_family_index: u32,
        window: *vk._screen_window,
    ) vk.Bool32 {
        return self.vki.getPhysicalDeviceScreenPresentationSupportQNX(physical_device, queue_family_index, window);
    }

    pub inline fn createDebugReportCallbackEXT(
        self: Self,
        p_create_info: *const vk.DebugReportCallbackCreateInfoEXT,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) InstanceDispatch.CreateDebugReportCallbackEXTError!vk.DebugReportCallbackEXT {
        return self.vki.createDebugReportCallbackEXT(self.handle, p_create_info, p_allocator);
    }

    pub inline fn destroyDebugReportCallbackEXT(
        self: Self,
        callback: vk.DebugReportCallbackEXT,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) void {
        return self.vki.destroyDebugReportCallbackEXT(self.handle, callback, p_allocator);
    }

    pub inline fn debugReportMessageEXT(
        self: Self,
        flags: vk.DebugReportFlagsEXT,
        object_type: vk.DebugReportObjectTypeEXT,
        object: u64,
        location: usize,
        message_code: i32,
        p_layer_prefix: [*:0]const u8,
        p_message: [*:0]const u8,
    ) void {
        return self.vki.debugReportMessageEXT(self.handle, flags, object_type, object, location, message_code, p_layer_prefix, p_message);
    }

    pub inline fn getPhysicalDeviceExternalImageFormatPropertiesNV(
        self: Self,
        physical_device: vk.PhysicalDevice,
        format: vk.Format,
        @"type": vk.ImageType,
        tiling: vk.ImageTiling,
        usage: vk.ImageUsageFlags,
        flags: vk.ImageCreateFlags,
        external_handle_type: vk.ExternalMemoryHandleTypeFlagsNV,
    ) InstanceDispatch.GetPhysicalDeviceExternalImageFormatPropertiesNVError!vk.ExternalImageFormatPropertiesNV {
        return self.getPhysicalDeviceExternalImageFormatPropertiesNV(physical_device, format, @"type", tiling, usage, flags, external_handle_type);
    }

    pub inline fn getPhysicalDeviceFeatures2(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_features: *vk.PhysicalDeviceFeatures2,
    ) void {
        return self.vki.getPhysicalDeviceFeatures2(physical_device, p_features);
    }

    pub inline fn getPhysicalDeviceProperties2(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_properties: *vk.PhysicalDeviceProperties2,
    ) void {
        return self.vki.getPhysicalDeviceProperties2(physical_device, p_properties);
    }

    pub inline fn getPhysicalDeviceFormatProperties2(
        self: Self,
        physical_device: vk.PhysicalDevice,
        format: vk.Format,
        p_format_properties: *vk.FormatProperties2,
    ) void {
        return self.vki.getPhysicalDeviceFormatProperties2(physical_device, format, p_format_properties);
    }

    pub inline fn getPhysicalDeviceImageFormatProperties2(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_image_format_info: *const vk.PhysicalDeviceImageFormatInfo2,
        p_image_format_properties: *vk.ImageFormatProperties2,
    ) InstanceDispatch.GetPhysicalDeviceImageFormatProperties2Error!void {
        return self.vki.getPhysicalDeviceImageFormatProperties2(physical_device, p_image_format_info, p_image_format_properties);
    }

    pub inline fn getPhysicalDeviceQueueFamilyProperties2(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_queue_family_property_count: *u32,
        p_queue_family_properties: ?[*]vk.QueueFamilyProperties2,
    ) void {
        return self.vki.getPhysicalDeviceQueueFamilyProperties2(physical_device, p_queue_family_property_count, p_queue_family_properties);
    }

    pub inline fn getPhysicalDeviceMemoryProperties2(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_memory_properties: *vk.PhysicalDeviceMemoryProperties2,
    ) void {
        return self.vki.getPhysicalDeviceMemoryProperties2(physical_device, p_memory_properties);
    }

    pub inline fn getPhysicalDeviceSparseImageFormatProperties2(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_format_info: *const vk.PhysicalDeviceSparseImageFormatInfo2,
        p_property_count: *u32,
        p_properties: ?[*]vk.SparseImageFormatProperties2,
    ) void {
        return self.vki.getPhysicalDeviceSparseImageFormatProperties2(physical_device, p_format_info, p_property_count, p_properties);
    }

    pub inline fn getPhysicalDeviceExternalBufferProperties(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_external_buffer_info: *const vk.PhysicalDeviceExternalBufferInfo,
        p_external_buffer_properties: *vk.ExternalBufferProperties,
    ) void {
        return self.vki.getPhysicalDeviceExternalBufferProperties(physical_device, p_external_buffer_info, p_external_buffer_properties);
    }

    pub inline fn getPhysicalDeviceExternalSemaphoreProperties(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_external_semaphore_info: *const vk.PhysicalDeviceExternalSemaphoreInfo,
        p_external_semaphore_properties: *vk.ExternalSemaphoreProperties,
    ) void {
        return self.vki.getPhysicalDeviceExternalSemaphoreProperties(physical_device, p_external_semaphore_info, p_external_semaphore_properties);
    }

    pub inline fn getPhysicalDeviceExternalFenceProperties(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_external_fence_info: *const vk.PhysicalDeviceExternalFenceInfo,
        p_external_fence_properties: *vk.ExternalFenceProperties,
    ) void {
        return self.vki.getPhysicalDeviceExternalFenceProperties(physical_device, p_external_fence_info, p_external_fence_properties);
    }

    pub inline fn releaseDisplayEXT(
        self: Self,
        physical_device: vk.PhysicalDevice,
        display: vk.DisplayKHR,
    ) InstanceDispatch.ReleaseDisplayEXTError!void {
        return self.vki.releaseDisplayEXT(physical_device, display);
    }

    pub inline fn acquireXlibDisplayEXT(
        self: Self,
        physical_device: vk.PhysicalDevice,
        dpy: *vk.Display,
        display: vk.DisplayKHR,
    ) InstanceDispatch.AcquireXlibDisplayEXTError!void {
        return self.vki.acquireXlibDisplayEXT(physical_device, dpy, display);
    }

    pub inline fn getRandROutputDisplayEXT(
        self: Self,
        physical_device: vk.PhysicalDevice,
        dpy: *vk.Display,
        rr_output: vk.RROutput,
    ) InstanceDispatch.GetRandROutputDisplayEXTError!vk.DisplayKHR {
        return self.vki.getRandROutputDisplayEXT(physical_device, dpy, rr_output);
    }

    pub inline fn acquireWinrtDisplayNV(
        self: Self,
        physical_device: vk.PhysicalDevice,
        display: vk.DisplayKHR,
    ) InstanceDispatch.AcquireWinrtDisplayNVError!void {
        return self.vki.acquireWinrtDisplayNV(physical_device, display);
    }

    pub inline fn getWinrtDisplayNV(
        self: Self,
        physical_device: vk.PhysicalDevice,
        device_relative_id: u32,
    ) InstanceDispatch.GetWinrtDisplayNVError!vk.DisplayKHR {
        return self.vki.getWinrtDisplayNV(physical_device, device_relative_id);
    }

    pub inline fn getPhysicalDeviceSurfaceCapabilities2EXT(
        self: Self,
        physical_device: vk.PhysicalDevice,
        surface: vk.SurfaceKHR,
        p_surface_capabilities: *vk.SurfaceCapabilities2EXT,
    ) InstanceDispatch.GetPhysicalDeviceSurfaceCapabilities2EXTError!void {
        return self.vki.getPhysicalDeviceSurfaceCapabilities2EXT(physical_device, surface, p_surface_capabilities);
    }

    pub inline fn enumeratePhysicalDeviceGroups(
        self: Self,
        p_physical_device_group_count: *u32,
        p_physical_device_group_properties: ?[*]vk.PhysicalDeviceGroupProperties,
    ) InstanceDispatch.EnumeratePhysicalDeviceGroupsError!vk.Result {
        return self.vki.enumeratePhysicalDeviceGroups(self.handle, p_physical_device_group_count, p_physical_device_group_properties);
    }

    pub inline fn getPhysicalDevicePresentRectanglesKHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        surface: vk.SurfaceKHR,
        p_rect_count: *u32,
        p_rects: ?[*]vk.Rect2D,
    ) InstanceDispatch.GetPhysicalDevicePresentRectanglesKHRError!vk.Result {
        return self.vki.getPhysicalDevicePresentRectanglesKHR(physical_device, surface, p_rect_count, p_rects);
    }

    pub inline fn createIosSurfaceMVK(
        self: Self,
        p_create_info: *const vk.IOSSurfaceCreateInfoMVK,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) InstanceDispatch.CreateIosSurfaceMVKError!vk.SurfaceKHR {
        return self.vki.createIosSurfaceMVK(self.handle, p_create_info, p_allocator);
    }

    pub inline fn createMacOsSurfaceMVK(
        self: Self,
        p_create_info: *const vk.MacOSSurfaceCreateInfoMVK,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) InstanceDispatch.CreateMacOsSurfaceMVKError!vk.SurfaceKHR {
        return self.vki.createMacOsSurfaceMVK(self.handle, p_create_info, p_allocator);
    }

    pub inline fn createMetalSurfaceEXT(
        self: Self,
        p_create_info: *const vk.MetalSurfaceCreateInfoEXT,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) InstanceDispatch.CreateMetalSurfaceEXTError!vk.SurfaceKHR {
        return self.vki.createMetalSurfaceEXT(self.handle, p_create_info, p_allocator);
    }

    // ==============

    pub inline fn getPhysicalDeviceMultisamplePropertiesEXT(
        self: Self,
        physical_device: vk.PhysicalDevice,
        samples: vk.SampleCountFlags,
        p_multisample_properties: *vk.MultisamplePropertiesEXT,
    ) void {
        return self.vki.getPhysicalDeviceMultisamplePropertiesEXT(physical_device, samples, p_multisample_properties);
    }

    pub inline fn getPhysicalDeviceSurfaceCapabilities2KHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_surface_info: *const vk.PhysicalDeviceSurfaceInfo2KHR,
        p_surface_capabilities: *vk.SurfaceCapabilities2KHR,
    ) InstanceDispatch.GetPhysicalDeviceSurfaceCapabilities2KHRError!void {
        return self.vki.getPhysicalDeviceSurfaceCapabilities2KHR(physical_device, p_surface_info, p_surface_capabilities);
    }

    pub inline fn getPhysicalDeviceSurfaceFormats2KHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_surface_info: *const vk.PhysicalDeviceSurfaceInfo2KHR,
        p_surface_format_count: *u32,
        p_surface_formats: ?[*]vk.SurfaceFormat2KHR,
    ) InstanceDispatch.GetPhysicalDeviceSurfaceFormats2KHRError!vk.Result {
        return self.vki.getPhysicalDeviceSurfaceFormats2KHR(physical_device, p_surface_info, p_surface_format_count, p_surface_formats);
    }

    pub inline fn getPhysicalDeviceDisplayProperties2KHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_property_count: *u32,
        p_properties: ?[*]vk.DisplayProperties2KHR,
    ) InstanceDispatch.GetPhysicalDeviceDisplayProperties2KHRError!vk.Result {
        return self.vki.getPhysicalDeviceDisplayProperties2KHR(physical_device, p_property_count, p_properties);
    }

    pub inline fn getPhysicalDeviceDisplayPlaneProperties2KHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_property_count: *u32,
        p_properties: ?[*]vk.DisplayPlaneProperties2KHR,
    ) InstanceDispatch.GetPhysicalDeviceDisplayPlaneProperties2KHRError!vk.Result {
        return self.vki.getPhysicalDeviceDisplayPlaneProperties2KHR(physical_device, p_property_count, p_properties);
    }

    pub inline fn getDisplayModeProperties2KHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        display: vk.DisplayKHR,
        p_property_count: *u32,
        p_properties: ?[*]vk.DisplayModeProperties2KHR,
    ) InstanceDispatch.GetDisplayModeProperties2KHRError!vk.Result {
        return self.vki.getDisplayModeProperties2KHR(physical_device, display, p_property_count, p_properties);
    }

    pub inline fn getDisplayPlaneCapabilities2KHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_display_plane_info: *const vk.DisplayPlaneInfo2KHR,
        p_capabilities: *vk.DisplayPlaneCapabilities2KHR,
    ) InstanceDispatch.GetDisplayPlaneCapabilities2KHRError!void {
        return self.vki.getDisplayPlaneCapabilities2KHR(physical_device, p_display_plane_info, p_capabilities);
    }

    pub inline fn getPhysicalDeviceCalibrateableTimeDomainsEXT(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_time_domain_count: *u32,
        p_time_domains: ?[*]vk.TimeDomainEXT,
    ) InstanceDispatch.GetPhysicalDeviceCalibrateableTimeDomainsEXTError!vk.Result {
        return self.vki.getPhysicalDeviceCalibrateableTimeDomainsEXT(physical_device, p_time_domain_count, p_time_domains);
    }

    pub inline fn createDebugUtilsMessengerEXT(
        self: Self,
        p_create_info: *const vk.DebugUtilsMessengerCreateInfoEXT,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) InstanceDispatch.CreateDebugUtilsMessengerEXTError!vk.DebugUtilsMessengerEXT {
        return self.vki.createDebugUtilsMessengerEXT(self.handle, p_create_info, p_allocator);
    }

    pub inline fn destroyDebugUtilsMessengerEXT(
        self: Self,
        messenger: vk.DebugUtilsMessengerEXT,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) void {
        return self.vki.destroyDebugUtilsMessengerEXT(self.handle, messenger, p_allocator);
    }

    pub inline fn submitDebugUtilsMessageEXT(
        self: Self,
        message_severity: vk.DebugUtilsMessageSeverityFlagsEXT,
        message_types: vk.DebugUtilsMessageTypeFlagsEXT,
        p_callback_data: *const vk.DebugUtilsMessengerCallbackDataEXT,
    ) void {
        return self.vki.submitDebugUtilsMessageEXT(self.handle, message_severity, message_types, p_callback_data);
    }

    pub inline fn getPhysicalDeviceCooperativeMatrixPropertiesNV(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_property_count: *u32,
        p_properties: ?[*]vk.CooperativeMatrixPropertiesNV,
    ) InstanceDispatch.GetPhysicalDeviceCooperativeMatrixPropertiesNVError!vk.Result {
        return self.vki.getPhysicalDeviceCooperativeMatrixPropertiesNV(physical_device, p_property_count, p_properties);
    }

    pub inline fn getPhysicalDeviceSurfacePresentModes2EXT(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_surface_info: *const vk.PhysicalDeviceSurfaceInfo2KHR,
        p_present_mode_count: *u32,
        p_present_modes: ?[*]vk.PresentModeKHR,
    ) InstanceDispatch.GetPhysicalDeviceSurfacePresentModes2EXTError!vk.Result {
        return self.vki.getPhysicalDeviceSurfacePresentModes2EXT(physical_device, p_surface_info, p_present_mode_count, p_present_modes);
    }

    pub inline fn enumeratePhysicalDeviceQueueFamilyPerformanceQueryCountersKHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        queue_family_index: u32,
        p_counter_count: *u32,
        p_counters: ?[*]vk.PerformanceCounterKHR,
        p_counter_descriptions: ?[*]vk.PerformanceCounterDescriptionKHR,
    ) InstanceDispatch.EnumeratePhysicalDeviceQueueFamilyPerformanceQueryCountersKHRError!vk.Result {
        return self.vki.enumeratePhysicalDeviceQueueFamilyPerformanceQueryCountersKHR(physical_device, queue_family_index, p_counter_count, p_counters, p_counter_descriptions);
    }

    pub inline fn getPhysicalDeviceQueueFamilyPerformanceQueryPassesKHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_performance_query_create_info: *const vk.QueryPoolPerformanceCreateInfoKHR,
    ) u32 {
        return self.vki.getPhysicalDeviceQueueFamilyPerformanceQueryPassesKHR(physical_device, p_performance_query_create_info);
    }

    pub inline fn createHeadlessSurfaceEXT(
        self: Self,
        p_create_info: *const vk.HeadlessSurfaceCreateInfoEXT,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) InstanceDispatch.CreateHeadlessSurfaceEXTError!vk.SurfaceKHR {
        return self.vki.createHeadlessSurfaceEXT(self.handle, p_create_info, p_allocator);
    }

    pub inline fn getPhysicalDeviceSupportedFramebufferMixedSamplesCombinationsNV(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_combination_count: *u32,
        p_combinations: ?[*]vk.FramebufferMixedSamplesCombinationNV,
    ) InstanceDispatch.GetPhysicalDeviceSupportedFramebufferMixedSamplesCombinationsNVError!vk.Result {
        return self.vki.getPhysicalDeviceSupportedFramebufferMixedSamplesCombinationsNV(physical_device, p_combination_count, p_combinations);
    }

    pub inline fn getPhysicalDeviceToolPropertiesEXT(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_tool_count: *u32,
        p_tool_properties: ?[*]vk.PhysicalDeviceToolPropertiesEXT,
    ) InstanceDispatch.GetPhysicalDeviceToolPropertiesEXTError!vk.Result {
        return self.vki.getPhysicalDeviceToolPropertiesEXT(physical_device, p_tool_count, p_tool_properties);
    }

    pub inline fn getPhysicalDeviceFragmentShadingRatesKHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_fragment_shading_rate_count: *u32,
        p_fragment_shading_rates: ?[*]vk.PhysicalDeviceFragmentShadingRateKHR,
    ) InstanceDispatch.GetPhysicalDeviceFragmentShadingRatesKHRError!vk.Result {
        return self.vki.getPhysicalDeviceFragmentShadingRatesKHR(physical_device, p_fragment_shading_rate_count, p_fragment_shading_rates);
    }

    pub inline fn getPhysicalDeviceVideoCapabilitiesKHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_video_profile: *const vk.VideoProfileKHR,
        p_capabilities: *vk.VideoCapabilitiesKHR,
    ) InstanceDispatch.GetPhysicalDeviceVideoCapabilitiesKHRError!void {
        return self.vki.getPhysicalDeviceVideoCapabilitiesKHR(physical_device, p_video_profile, p_capabilities);
    }

    pub inline fn getPhysicalDeviceVideoFormatPropertiesKHR(
        self: Self,
        physical_device: vk.PhysicalDevice,
        p_video_format_info: *const vk.PhysicalDeviceVideoFormatInfoKHR,
        p_video_format_property_count: *u32,
        p_video_format_properties: ?[*]vk.VideoFormatPropertiesKHR,
    ) InstanceDispatch.GetPhysicalDeviceVideoFormatPropertiesKHRError!vk.Result {
        return self.vki.getPhysicalDeviceVideoFormatPropertiesKHR(physical_device, p_video_format_info, p_video_format_property_count, p_video_format_properties);
    }
};
