const std = @import("std");
pub const vk = @import("vendor/vulkan-zig/vk.zig");

pub const VulkanEntry = @import("vulkan_entry.zig").VulkanEntry;
const instance = @import("vulkan_instance.zig");
pub const VulkanInstance = instance.VulkanInstance;
pub const InstanceDispatch = instance.InstanceDispatch;

pub const physical_device = @import("vulkan_physical_device.zig");
pub const PhysicalDeviceInfo = physical_device.PhysicalDeviceInfo;
pub const PhysicalDeviceRequirements = physical_device.PhysicalDeviceRequirements;
pub const QueueFamilyIndices = physical_device.QueueFamilyIndices;
pub const SwapchainSupportInfo = physical_device.SwapchainSupportInfo;

pub const surface = @import("vulkan_surface.zig");

pub const logical_device = @import("vulkan_logical_device.zig");
pub const Queues = logical_device.Queues;
pub const VulkanDevice = logical_device.VulkanDevice;

pub const renderer = @import("renderer.zig");
pub const VulkanContext = renderer.VulkanContext;

pub const swapchain = @import("vulkan_swapchain.zig");
pub const Swapchain = swapchain.Swapchain;
