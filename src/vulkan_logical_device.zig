const std = @import("std");
const builtin = @import("builtin");
const log = std.log.scoped(.vulkan_logical_device);
const vulkan_types = @import("vulkan_types.zig");
const vk = vulkan_types.vk;
const VulkanInstance = vulkan_types.VulkanInstance;
const QueueFamilyIndices = vulkan_types.QueueFamilyIndices;

pub const Queues = struct {
    graphics: vk.Queue,
    present: vk.Queue,
    compute: vk.Queue,
    transfer: vk.Queue,

    pub fn get(device: VulkanDevice, queue_families: QueueFamilyIndices) Queues {
        // the first queue in the family
        const queue_index = 0;

        return Queues{
            .graphics = if (queue_families.graphics) |queue| device.getDeviceQueue(queue, queue_index) else vk.Queue.null_handle,
            .present = if (queue_families.present) |queue| device.getDeviceQueue(queue, queue_index) else .null_handle,
            .compute = if (queue_families.compute) |queue| device.getDeviceQueue(queue, queue_index) else .null_handle,
            .transfer = if (queue_families.transfer) |queue| device.getDeviceQueue(queue, queue_index) else .null_handle,
        };
    }
};

pub const VulkanDevice = struct {
    handle: vk.Device,
    vkd: DeviceDispatch,

    pub usingnamespace impl;

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

        const device = try instance.createDevice(physical_device, &create_info, null);
        const vkd = try DeviceDispatch.load(device, instance.vki.dispatch.vkGetDeviceProcAddr);
        // errdefer vkd.destroyDevice(device, null);

        return VulkanDevice{
            .handle = device,
            .vkd = vkd,
        };
    }
};

const DeviceDispatch = vk.DeviceWrapper(.{
    .destroyDevice = true,
    .getDeviceQueue = true,
    // .queueSubmit = true,
    // .queueWaitIdle = true,
    // .deviceWaitIdle = true,
    // .allocateMemory = true,
    // .freeMemory = true,
    // .mapMemory = true,
    // .unmapMemory = true,
    // .flushMappedMemoryRanges = true,
    // .invalidateMappedMemoryRanges = true,
    // .getDeviceMemoryCommitment = true,
    // .getBufferMemoryRequirements = true,
    // .bindBufferMemory = true,
    // .getImageMemoryRequirements = true,
    // .bindImageMemory = true,
    // .getImageSparseMemoryRequirements = true,
    // .queueBindSparse = true,
    // .createFence = true,
    // .destroyFence = true,
    // .resetFences = true,
    // .getFenceStatus = true,
    // .waitForFences = true,
    // .createSemaphore = true,
    // .destroySemaphore = true,
    // .createEvent = true,
    // .destroyEvent = true,
    // .getEventStatus = true,
    // .setEvent = true,
    // .resetEvent = true,
    // .createQueryPool = true,
    // .destroyQueryPool = true,
    // .getQueryPoolResults = true,
    // .resetQueryPool = true,
    // .createBuffer = true,
    // .destroyBuffer = true,
    // .createBufferView = true,
    // .destroyBufferView = true,
    // .createImage = true,
    // .destroyImage = true,
    // .getImageSubresourceLayout = true,
    .createImageView = true,
    .destroyImageView = true,
    // .createShaderModule = true,
    // .destroyShaderModule = true,
    // .createPipelineCache = true,
    // .destroyPipelineCache = true,
    // .getPipelineCacheData = true,
    // .mergePipelineCaches = true,
    // .createGraphicsPipelines = true,
    // .createComputePipelines = true,
    // .destroyPipeline = true,
    // .createPipelineLayout = true,
    // .destroyPipelineLayout = true,
    // .createSampler = true,
    // .destroySampler = true,
    // .createDescriptorSetLayout = true,
    // .destroyDescriptorSetLayout = true,
    // .createDescriptorPool = true,
    // .destroyDescriptorPool = true,
    // .resetDescriptorPool = true,
    // .allocateDescriptorSets = true,
    // .freeDescriptorSets = true,
    // .updateDescriptorSets = true,
    // .createFramebuffer = true,
    // .destroyFramebuffer = true,
    // .createRenderPass = true,
    // .destroyRenderPass = true,
    // .getRenderAreaGranularity = true,
    // .createCommandPool = true,
    // .destroyCommandPool = true,
    // .resetCommandPool = true,
    // .allocateCommandBuffers = true,
    // .freeCommandBuffers = true,
    // .beginCommandBuffer = true,
    // .endCommandBuffer = true,
    // .resetCommandBuffer = true,
    // .cmdBindPipeline = true,
    // .cmdSetViewport = true,
    // .cmdSetScissor = true,
    // .cmdSetLineWidth = true,
    // .cmdSetDepthBias = true,
    // .cmdSetBlendConstants = true,
    // .cmdSetDepthBounds = true,
    // .cmdSetStencilCompareMask = true,
    // .cmdSetStencilWriteMask = true,
    // .cmdSetStencilReference = true,
    // .cmdBindDescriptorSets = true,
    // .cmdBindIndexBuffer = true,
    // .cmdBindVertexBuffers = true,
    // .cmdDraw = true,
    // .cmdDrawIndexed = true,
    // .cmdDrawIndirect = true,
    // .cmdDrawIndexedIndirect = true,
    // .cmdDispatch = true,
    // .cmdDispatchIndirect = true,
    // .cmdCopyBuffer = true,
    // .cmdCopyImage = true,
    // .cmdBlitImage = true,
    // .cmdCopyBufferToImage = true,
    // .cmdCopyImageToBuffer = true,
    // .cmdUpdateBuffer = true,
    // .cmdFillBuffer = true,
    // .cmdClearColorImage = true,
    // .cmdClearDepthStencilImage = true,
    // .cmdClearAttachments = true,
    // .cmdResolveImage = true,
    // .cmdSetEvent = true,
    // .cmdResetEvent = true,
    // .cmdWaitEvents = true,
    // .cmdPipelineBarrier = true,
    // .cmdBeginQuery = true,
    // .cmdEndQuery = true,
    // .cmdBeginConditionalRenderingEXT = true,
    // .cmdEndConditionalRenderingEXT = true,
    // .cmdResetQueryPool = true,
    // .cmdWriteTimestamp = true,
    // .cmdCopyQueryPoolResults = true,
    // .cmdPushConstants = true,
    // .cmdBeginRenderPass = true,
    // .cmdNextSubpass = true,
    // .cmdEndRenderPass = true,
    // .cmdExecuteCommands = true,
    // .createSharedSwapchainsKHR = true,
    .createSwapchainKHR = true,
    .destroySwapchainKHR = true,
    .getSwapchainImagesKHR = true,
    // .acquireNextImageKHR = true,
    // .queuePresentKHR = true,
    // .debugMarkerSetObjectNameEXT = true,
    // .debugMarkerSetObjectTagEXT = true,
    // .cmdDebugMarkerBeginEXT = true,
    // .cmdDebugMarkerEndEXT = true,
    // .cmdDebugMarkerInsertEXT = true,
    // .getMemoryWin32HandleNV = true,
    // .cmdExecuteGeneratedCommandsNV = true,
    // .cmdPreprocessGeneratedCommandsNV = true,
    // .cmdBindPipelineShaderGroupNV = true,
    // .getGeneratedCommandsMemoryRequirementsNV = true,
    // .createIndirectCommandsLayoutNV = true,
    // .destroyIndirectCommandsLayoutNV = true,
    // .cmdPushDescriptorSetKHR = true,
    // .trimCommandPool = true,
    // .getMemoryWin32HandleKHR = true,
    // .getMemoryWin32HandlePropertiesKHR = true,
    // .getMemoryFdKHR = true,
    // .getMemoryFdPropertiesKHR = true,
    // .getMemoryZirconHandleFUCHSIA = true,
    // .getMemoryZirconHandlePropertiesFUCHSIA = true,
    // .getSemaphoreWin32HandleKHR = true,
    // .importSemaphoreWin32HandleKHR = true,
    // .getSemaphoreFdKHR = true,
    // .importSemaphoreFdKHR = true,
    // .getSemaphoreZirconHandleFUCHSIA = true,
    // .importSemaphoreZirconHandleFUCHSIA = true,
    // .getFenceWin32HandleKHR = true,
    // .importFenceWin32HandleKHR = true,
    // .getFenceFdKHR = true,
    // .importFenceFdKHR = true,
    // .displayPowerControlEXT = true,
    // .registerDeviceEventEXT = true,
    // .registerDisplayEventEXT = true,
    // .getSwapchainCounterEXT = true,
    // .getDeviceGroupPeerMemoryFeatures = true,
    // .bindBufferMemory2 = true,
    // .bindImageMemory2 = true,
    // .cmdSetDeviceMask = true,
    // .getDeviceGroupPresentCapabilitiesKHR = true,
    // .getDeviceGroupSurfacePresentModesKHR = true,
    // .acquireNextImage2KHR = true,
    // .cmdDispatchBase = true,
    // .createDescriptorUpdateTemplate = true,
    // .destroyDescriptorUpdateTemplate = true,
    // .updateDescriptorSetWithTemplate = true,
    // .cmdPushDescriptorSetWithTemplateKHR = true,
    // .setHdrMetadataEXT = true,
    // .getSwapchainStatusKHR = true,
    // .getRefreshCycleDurationGOOGLE = true,
    // .getPastPresentationTimingGOOGLE = true,
    // .cmdSetViewportWScalingNV = true,
    // .cmdSetDiscardRectangleEXT = true,
    // .cmdSetSampleLocationsEXT = true,
    // .getBufferMemoryRequirements2 = true,
    // .getImageMemoryRequirements2 = true,
    // .getImageSparseMemoryRequirements2 = true,
    // .createSamplerYcbcrConversion = true,
    // .destroySamplerYcbcrConversion = true,
    // .getDeviceQueue2 = true,
    // .createValidationCacheEXT = true,
    // .destroyValidationCacheEXT = true,
    // .getValidationCacheDataEXT = true,
    // .mergeValidationCachesEXT = true,
    // .getDescriptorSetLayoutSupport = true,
    // .getSwapchainGrallocUsageANDROID = true,
    // .getSwapchainGrallocUsage2ANDROID = true,
    // .acquireImageANDROID = true,
    // .queueSignalReleaseImageANDROID = true,
    // .getShaderInfoAMD = true,
    // .setLocalDimmingAMD = true,
    // .getCalibratedTimestampsEXT = true,
    // .setDebugUtilsObjectNameEXT = true,
    // .setDebugUtilsObjectTagEXT = true,
    // .queueBeginDebugUtilsLabelEXT = true,
    // .queueEndDebugUtilsLabelEXT = true,
    // .queueInsertDebugUtilsLabelEXT = true,
    // .cmdBeginDebugUtilsLabelEXT = true,
    // .cmdEndDebugUtilsLabelEXT = true,
    // .cmdInsertDebugUtilsLabelEXT = true,
    // .getMemoryHostPointerPropertiesEXT = true,
    // .cmdWriteBufferMarkerAMD = true,
    // .createRenderPass2 = true,
    // .cmdBeginRenderPass2 = true,
    // .cmdNextSubpass2 = true,
    // .cmdEndRenderPass2 = true,
    // .getSemaphoreCounterValue = true,
    // .waitSemaphores = true,
    // .signalSemaphore = true,
    // .getAndroidHardwareBufferPropertiesANDROID = true,
    // .getMemoryAndroidHardwareBufferANDROID = true,
    // .cmdDrawIndirectCount = true,
    // .cmdDrawIndexedIndirectCount = true,
    // .cmdSetCheckpointNV = true,
    // .getQueueCheckpointDataNV = true,
    // .cmdBindTransformFeedbackBuffersEXT = true,
    // .cmdBeginTransformFeedbackEXT = true,
    // .cmdEndTransformFeedbackEXT = true,
    // .cmdBeginQueryIndexedEXT = true,
    // .cmdEndQueryIndexedEXT = true,
    // .cmdDrawIndirectByteCountEXT = true,
    // .cmdSetExclusiveScissorNV = true,
    // .cmdBindShadingRateImageNV = true,
    // .cmdSetViewportShadingRatePaletteNV = true,
    // .cmdSetCoarseSampleOrderNV = true,
    // .cmdDrawMeshTasksNV = true,
    // .cmdDrawMeshTasksIndirectNV = true,
    // .cmdDrawMeshTasksIndirectCountNV = true,
    // .compileDeferredNV = true,
    // .createAccelerationStructureNV = true,
    // .destroyAccelerationStructureKHR = true,
    // .destroyAccelerationStructureNV = true,
    // .getAccelerationStructureMemoryRequirementsNV = true,
    // .bindAccelerationStructureMemoryNV = true,
    // .cmdCopyAccelerationStructureNV = true,
    // .cmdCopyAccelerationStructureKHR = true,
    // .copyAccelerationStructureKHR = true,
    // .cmdCopyAccelerationStructureToMemoryKHR = true,
    // .copyAccelerationStructureToMemoryKHR = true,
    // .cmdCopyMemoryToAccelerationStructureKHR = true,
    // .copyMemoryToAccelerationStructureKHR = true,
    // .cmdWriteAccelerationStructuresPropertiesKHR = true,
    // .cmdWriteAccelerationStructuresPropertiesNV = true,
    // .cmdBuildAccelerationStructureNV = true,
    // .writeAccelerationStructuresPropertiesKHR = true,
    // .cmdTraceRaysKHR = true,
    // .cmdTraceRaysNV = true,
    // .getRayTracingShaderGroupHandlesKHR = true,
    // .getRayTracingCaptureReplayShaderGroupHandlesKHR = true,
    // .getAccelerationStructureHandleNV = true,
    // .createRayTracingPipelinesNV = true,
    // .createRayTracingPipelinesKHR = true,
    // .cmdTraceRaysIndirectKHR = true,
    // .getDeviceAccelerationStructureCompatibilityKHR = true,
    // .getRayTracingShaderGroupStackSizeKHR = true,
    // .cmdSetRayTracingPipelineStackSizeKHR = true,
    // .getImageViewHandleNVX = true,
    // .getImageViewAddressNVX = true,
    // .getDeviceGroupSurfacePresentModes2EXT = true,
    // .acquireFullScreenExclusiveModeEXT = true,
    // .releaseFullScreenExclusiveModeEXT = true,
    // .acquireProfilingLockKHR = true,
    // .releaseProfilingLockKHR = true,
    // .getImageDrmFormatModifierPropertiesEXT = true,
    // .getBufferOpaqueCaptureAddress = true,
    // .getBufferDeviceAddress = true,
    // .initializePerformanceApiINTEL = true,
    // .uninitializePerformanceApiINTEL = true,
    // .cmdSetPerformanceMarkerINTEL = true,
    // .cmdSetPerformanceStreamMarkerINTEL = true,
    // .cmdSetPerformanceOverrideINTEL = true,
    // .acquirePerformanceConfigurationINTEL = true,
    // .releasePerformanceConfigurationINTEL = true,
    // .queueSetPerformanceConfigurationINTEL = true,
    // .getPerformanceParameterINTEL = true,
    // .getDeviceMemoryOpaqueCaptureAddress = true,
    // .getPipelineExecutablePropertiesKHR = true,
    // .getPipelineExecutableStatisticsKHR = true,
    // .getPipelineExecutableInternalRepresentationsKHR = true,
    // .cmdSetLineStippleEXT = true,
    // .createAccelerationStructureKHR = true,
    // .cmdBuildAccelerationStructuresKHR = true,
    // .cmdBuildAccelerationStructuresIndirectKHR = true,
    // .buildAccelerationStructuresKHR = true,
    // .getAccelerationStructureDeviceAddressKHR = true,
    // .createDeferredOperationKHR = true,
    // .destroyDeferredOperationKHR = true,
    // .getDeferredOperationMaxConcurrencyKHR = true,
    // .getDeferredOperationResultKHR = true,
    // .deferredOperationJoinKHR = true,
    // .cmdSetCullModeEXT = true,
    // .cmdSetFrontFaceEXT = true,
    // .cmdSetPrimitiveTopologyEXT = true,
    // .cmdSetViewportWithCountEXT = true,
    // .cmdSetScissorWithCountEXT = true,
    // .cmdBindVertexBuffers2EXT = true,
    // .cmdSetDepthTestEnableEXT = true,
    // .cmdSetDepthWriteEnableEXT = true,
    // .cmdSetDepthCompareOpEXT = true,
    // .cmdSetDepthBoundsTestEnableEXT = true,
    // .cmdSetStencilTestEnableEXT = true,
    // .cmdSetStencilOpEXT = true,
    // .createPrivateDataSlotEXT = true,
    // .destroyPrivateDataSlotEXT = true,
    // .setPrivateDataEXT = true,
    // .getPrivateDataEXT = true,
    // .cmdCopyBuffer2KHR = true,
    // .cmdCopyImage2KHR = true,
    // .cmdBlitImage2KHR = true,
    // .cmdCopyBufferToImage2KHR = true,
    // .cmdCopyImageToBuffer2KHR = true,
    // .cmdResolveImage2KHR = true,
    // .cmdSetFragmentShadingRateKHR = true,
    // .cmdSetFragmentShadingRateEnumNV = true,
    // .getAccelerationStructureBuildSizesKHR = true,
    // .cmdSetVertexInputEXT = true,
    // .cmdSetColorWriteEnableEXT = true,
    // .cmdSetEvent2KHR = true,
    // .cmdResetEvent2KHR = true,
    // .cmdWaitEvents2KHR = true,
    // .cmdPipelineBarrier2KHR = true,
    // .queueSubmit2KHR = true,
    // .cmdWriteTimestamp2KHR = true,
    // .cmdWriteBufferMarker2AMD = true,
    // .getQueueCheckpointData2NV = true,
    // .createVideoSessionKHR = true,
    // .destroyVideoSessionKHR = true,
    // .createVideoSessionParametersKHR = true,
    // .updateVideoSessionParametersKHR = true,
    // .destroyVideoSessionParametersKHR = true,
    // .getVideoSessionMemoryRequirementsKHR = true,
    // .bindVideoSessionMemoryKHR = true,
    // .cmdDecodeVideoKHR = true,
    // .cmdBeginVideoCodingKHR = true,
    // .cmdControlVideoCodingKHR = true,
    // .cmdEndVideoCodingKHR = true,
    // .cmdEncodeVideoKHR = true,
});

pub const impl = struct {
    const Self = VulkanDevice;

    pub inline fn destroyDevice(
        self: Self,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) void {
        return self.vkd.destroyDevice(self.handle, p_allocator);
    }

    pub inline fn getDeviceQueue(
        self: Self,
        queue_family_index: u32,
        queue_index: u32,
    ) vk.Queue {
        return self.vkd.getDeviceQueue(self.handle, queue_family_index, queue_index);
    }

    // =========================

    pub inline fn createImageView(
        self: Self,
        p_create_info: *const vk.ImageViewCreateInfo,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) DeviceDispatch.CreateImageViewError!vk.ImageView {
        return self.vkd.createImageView(self.handle, p_create_info, p_allocator);
    }

    pub inline fn destroyImageView(
        self: Self,
        image_view: vk.ImageView,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) void {
        return self.vkd.destroyImageView(self.handle, image_view, p_allocator);
    }

    // =========================

    pub inline fn createSwapchainKHR(
        self: Self,
        p_create_info: *const vk.SwapchainCreateInfoKHR,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) DeviceDispatch.CreateSwapchainKHRError!vk.SwapchainKHR {
        return self.vkd.createSwapchainKHR(self.handle, p_create_info, p_allocator);
    }

    pub inline fn destroySwapchainKHR(
        self: Self,
        swapchain: vk.SwapchainKHR,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) void {
        return self.vkd.destroySwapchainKHR(self.handle, swapchain, p_allocator);
    }

    pub inline fn getSwapchainImagesKHR(
        self: Self,
        swapchain: vk.SwapchainKHR,
        p_swapchain_image_count: *u32,
        p_swapchain_images: ?[*]vk.Image,
    ) DeviceDispatch.GetSwapchainImagesKHRError!vk.Result {
        return self.vkd.getSwapchainImagesKHR(self.handle, swapchain, p_swapchain_image_count, p_swapchain_images);
    }

    // ====================

    pub inline fn acquireNextImageKHR(
        self: Self,
        swapchain: vk.SwapchainKHR,
        timeout: u64,
        semaphore: vk.Semaphore,
        fence: vk.Fence,
    ) DeviceDispatch.AcquireNextImageKHRError!vk.AcquireNextImageKHRResult {
        return self.vkd.acquireNextImageKHR(self.handle, swapchain, timeout, semaphore, fence);
    }
    pub inline fn queuePresentKHR(
        self: Self,
        queue: vk.Queue,
        p_present_info: *const vk.PresentInfoKHR,
    ) DeviceDispatch.QueuePresentKHRError!vk.Result {
        return self.queuePresentKHR(queue, p_present_info);
    }

    pub inline fn debugMarkerSetObjectNameEXT(
        self: Self,
        p_name_info: *const vk.DebugMarkerObjectNameInfoEXT,
    ) DeviceDispatch.DebugMarkerSetObjectNameEXTError!void {
        return self.vkd.debugMarkerSetObjectNameEXT(self.handle, p_name_info);
    }

    pub inline fn debugMarkerSetObjectTagEXT(
        self: Self,
        p_tag_info: *const vk.DebugMarkerObjectTagInfoEXT,
    ) DeviceDispatch.DebugMarkerSetObjectTagEXTError!void {
        return self.vkd.debugMarkerSetObjectTagEXT(self.handle, p_tag_info);
    }

    pub inline fn cmdDebugMarkerBeginEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_marker_info: *const vk.DebugMarkerMarkerInfoEXT,
    ) void {
        self.vkd.cmdDebugMarkerBeginEXT(self.handle, command_buffer, p_marker_info);
    }

    pub inline fn cmdDebugMarkerEndEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
    ) void {
        self.vkd.cmdDebugMarkerEndEXT(command_buffer);
    }

    pub inline fn cmdDebugMarkerInsertEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_marker_info: *const vk.DebugMarkerMarkerInfoEXT,
    ) void {
        self.vkd.cmdDebugMarkerInsertEXT(command_buffer, p_marker_info);
    }

    pub inline fn getMemoryWin32HandleNV(
        self: Self,
        memory: vk.DeviceMemory,
        handle_type: vk.ExternalMemoryHandleTypeFlagsNV,
        p_handle: *vk.HANDLE,
    ) DeviceDispatch.GetMemoryWin32HandleNVError!void {
        return self.vkd.getMemoryWin32HandleNV(self.handle, memory, handle_type, p_handle);
    }
    pub inline fn cmdExecuteGeneratedCommandsNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        is_preprocessed: vk.Bool32,
        p_generated_commands_info: *const vk.GeneratedCommandsInfoNV,
    ) void {
        self.vkd.cmdExecuteGeneratedCommandsNV(command_buffer, is_preprocessed, p_generated_commands_info);
    }
    pub inline fn cmdPreprocessGeneratedCommandsNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_generated_commands_info: *const vk.GeneratedCommandsInfoNV,
    ) void {
        self.vkd.cmdPreprocessGeneratedCommandsNV(command_buffer, p_generated_commands_info);
    }

    pub inline fn cmdBindPipelineShaderGroupNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        pipeline_bind_point: vk.PipelineBindPoint,
        pipeline: vk.Pipeline,
        group_index: u32,
    ) void {
        self.vkd.cmdBindPipelineShaderGroupNV(command_buffer, pipeline_bind_point, pipeline, group_index);
    }
    pub inline fn getGeneratedCommandsMemoryRequirementsNV(
        self: Self,
        p_info: *const vk.GeneratedCommandsMemoryRequirementsInfoNV,
        p_memory_requirements: *vk.MemoryRequirements2,
    ) void {
        self.vkd.getGeneratedCommandsMemoryRequirementsNV(self.handle, p_info, p_memory_requirements);
    }

    pub inline fn createIndirectCommandsLayoutNV(
        self: Self,
        p_create_info: *const vk.IndirectCommandsLayoutCreateInfoNV,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) DeviceDispatch.CreateIndirectCommandsLayoutNVError!vk.IndirectCommandsLayoutNV {
        return self.vkd.createIndirectCommandsLayoutNV(self.handle, p_create_info, p_allocator);
    }

    pub inline fn destroyIndirectCommandsLayoutNV(
        self: Self,
        indirect_commands_layout: vk.IndirectCommandsLayoutNV,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) void {
        self.vkd.destroyIndirectCommandsLayoutNV(self.handle, indirect_commands_layout, p_allocator);
    }
    pub inline fn cmdPushDescriptorSetKHR(
        self: Self,
        command_buffer: vk.CommandBuffer,
        pipeline_bind_point: vk.PipelineBindPoint,
        layout: vk.PipelineLayout,
        set: u32,
        descriptor_write_count: u32,
        p_descriptor_writes: [*]const vk.WriteDescriptorSet,
    ) void {
        self.vkd.cmdPushDescriptorSetKHR(command_buffer, pipeline_bind_point, layout, set, descriptor_write_count, p_descriptor_writes);
    }

    pub inline fn trimCommandPool(
        self: Self,
        command_pool: vk.CommandPool,
        flags: vk.CommandPoolTrimFlags,
    ) void {
        self.vkd.trimCommandPool(self.handle, command_pool, flags);
    }

    pub inline fn getMemoryWin32HandleKHR(
        self: Self,
        p_get_win_32_handle_info: *const vk.MemoryGetWin32HandleInfoKHR,
        p_handle: *vk.HANDLE,
    ) DeviceDispatch.GetMemoryWin32HandleKHRError!void {
        return self.vkd.getMemoryWin32HandleKHR(self.handle, p_get_win_32_handle_info, p_handle);
    }

    pub inline fn getMemoryWin32HandlePropertiesKHR(
        self: Self,
        handle_type: vk.ExternalMemoryHandleTypeFlags,
        handle: vk.HANDLE,
        p_memory_win_32_handle_properties: *vk.MemoryWin32HandlePropertiesKHR,
    ) DeviceDispatch.GetMemoryWin32HandlePropertiesKHRError!void {
        return self.vkd.getMemoryWin32HandlePropertiesKHR(self.handle, handle_type, handle, p_memory_win_32_handle_properties);
    }

    pub inline fn getMemoryFdKHR(
        self: Self,
        p_get_fd_info: *const vk.MemoryGetFdInfoKHR,
    ) DeviceDispatch.GetMemoryFdKHRError!c_int {
        return self.vkd.getMemoryFdKHR(self.handle, p_get_fd_info);
    }

    pub inline fn getMemoryFdPropertiesKHR(
        self: Self,
        handle_type: vk.ExternalMemoryHandleTypeFlags,
        fd: c_int,
        p_memory_fd_properties: *vk.MemoryFdPropertiesKHR,
    ) DeviceDispatch.GetMemoryFdPropertiesKHRError!void {
        return self.vkd.getMemoryFdPropertiesKHR(self.handle, handle_type, fd, p_memory_fd_properties);
    }

    pub inline fn getMemoryZirconHandleFUCHSIA(
        self: Self,
        p_get_zircon_handle_info: *const vk.MemoryGetZirconHandleInfoFUCHSIA,
        p_zircon_handle: *vk.zx_handle_t,
    ) DeviceDispatch.GetMemoryZirconHandleFUCHSIAError!void {
        return self.vkd.getMemoryZirconHandleFUCHSIA(self.handle, p_get_zircon_handle_info, p_zircon_handle);
    }

    pub inline fn getMemoryZirconHandlePropertiesFUCHSIA(
        self: Self,
        handle_type: vk.ExternalMemoryHandleTypeFlags,
        zircon_handle: vk.zx_handle_t,
        p_memory_zircon_handle_properties: *vk.MemoryZirconHandlePropertiesFUCHSIA,
    ) DeviceDispatch.GetMemoryZirconHandlePropertiesFUCHSIAError!void {
        return self.vkd.getMemoryZirconHandlePropertiesFUCHSIA(self.handle, handle_type, zircon_handle, p_memory_zircon_handle_properties);
    }

    pub inline fn getMemoryRemoteAddressNV(
        self: Self,
        p_memory_get_remote_address_info: *const vk.MemoryGetRemoteAddressInfoNV,
    ) DeviceDispatch.GetMemoryRemoteAddressNVError!vk.RemoteAddressNV {
        return self.vkd.getMemoryRemoteAddressNV(self.handle, p_memory_get_remote_address_info);
    }

    pub inline fn getSemaphoreWin32HandleKHR(
        self: Self,
        p_get_win_32_handle_info: *const vk.SemaphoreGetWin32HandleInfoKHR,
        p_handle: *vk.HANDLE,
    ) DeviceDispatch.GetSemaphoreWin32HandleKHRError!void {
        return self.vkd.getSemaphoreWin32HandleKHR(self.handle, p_get_win_32_handle_info, p_handle);
    }

    pub inline fn importSemaphoreWin32HandleKHR(
        self: Self,
        p_import_semaphore_win_32_handle_info: *const vk.ImportSemaphoreWin32HandleInfoKHR,
    ) DeviceDispatch.ImportSemaphoreWin32HandleKHRError!void {
        return self.vkd.importSemaphoreWin32HandleKHR(self.handle, p_import_semaphore_win_32_handle_info);
    }

    pub inline fn getSemaphoreFdKHR(
        self: Self,
        p_get_fd_info: *const vk.SemaphoreGetFdInfoKHR,
    ) DeviceDispatch.GetSemaphoreFdKHRError!c_int {
        return self.vkd.getSemaphoreFdKHR(self.handle, p_get_fd_info);
    }

    pub inline fn importSemaphoreFdKHR(
        self: Self,
        p_import_semaphore_fd_info: *const vk.ImportSemaphoreFdInfoKHR,
    ) DeviceDispatch.ImportSemaphoreFdKHRError!void {
        return self.vkd.importSemaphoreFdKHR(self.handle, p_import_semaphore_fd_info);
    }

    pub inline fn getSemaphoreZirconHandleFUCHSIA(
        self: Self,
        p_get_zircon_handle_info: *const vk.SemaphoreGetZirconHandleInfoFUCHSIA,
        p_zircon_handle: *vk.zx_handle_t,
    ) DeviceDispatch.GetSemaphoreZirconHandleFUCHSIAError!void {
        return self.vkd.getSemaphoreZirconHandleFUCHSIA(self.handle, p_get_zircon_handle_info, p_zircon_handle);
    }

    pub inline fn importSemaphoreZirconHandleFUCHSIA(
        self: Self,
        p_import_semaphore_zircon_handle_info: *const vk.ImportSemaphoreZirconHandleInfoFUCHSIA,
    ) DeviceDispatch.ImportSemaphoreZirconHandleFUCHSIAError!void {
        return self.vkd.importSemaphoreZirconHandleFUCHSIA(self.handle, p_import_semaphore_zircon_handle_info);
    }

    pub inline fn getFenceWin32HandleKHR(
        self: Self,
        p_get_win_32_handle_info: *const vk.FenceGetWin32HandleInfoKHR,
        p_handle: *vk.HANDLE,
    ) DeviceDispatch.GetFenceWin32HandleKHRError!void {
        return self.vkd.getFenceWin32HandleKHR(self.handle, p_get_win_32_handle_info, p_handle);
    }

    pub inline fn importFenceWin32HandleKHR(
        self: Self,
        p_import_fence_win_32_handle_info: *const vk.ImportFenceWin32HandleInfoKHR,
    ) DeviceDispatch.ImportFenceWin32HandleKHRError!void {
        return self.vkd.importFenceWin32HandleKHR(self.handle, p_import_fence_win_32_handle_info);
    }

    pub inline fn getFenceFdKHR(
        self: Self,
        p_get_fd_info: *const vk.FenceGetFdInfoKHR,
    ) DeviceDispatch.GetFenceFdKHRError!c_int {
        return self.vkd.getFenceFdKHR(self.handle, p_get_fd_info);
    }

    pub inline fn importFenceFdKHR(
        self: Self,
        p_import_fence_fd_info: *const vk.ImportFenceFdInfoKHR,
    ) DeviceDispatch.ImportFenceFdKHRError!void {
        return self.vkd.importFenceFdKHR(self.handle, p_import_fence_fd_info);
    }

    // =============

    pub inline fn displayPowerControlEXT(
        self: Self,
        display: vk.DisplayKHR,
        p_display_power_info: *const vk.DisplayPowerInfoEXT,
    ) DeviceDispatch.DisplayPowerControlEXTError!void {
        return self.vkd.displayPowerControlEXT(self.handle, display, p_display_power_info);
    }

    pub inline fn registerDeviceEventEXT(
        self: Self,
        p_device_event_info: *const vk.DeviceEventInfoEXT,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) DeviceDispatch.RegisterDeviceEventEXTError!vk.Fence {
        return self.vkd.registerDeviceEventEXT(self.handle, p_device_event_info, p_allocator);
    }
    pub inline fn registerDisplayEventEXT(
        self: Self,
        display: vk.DisplayKHR,
        p_display_event_info: *const vk.DisplayEventInfoEXT,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) DeviceDispatch.RegisterDisplayEventEXTError!vk.Fence {
        self.vkd.registerDisplayEventEXT(self.handle, display, p_display_event_info, p_allocator);
    }

    pub inline fn getSwapchainCounterEXT(
        self: Self,
        swapchain: vk.SwapchainKHR,
        counter: vk.SurfaceCounterFlagsEXT,
    ) DeviceDispatch.GetSwapchainCounterEXTError!u64 {
        return self.vkd.getSwapchainCounterEXT(self.handle, swapchain, counter);
    }

    pub inline fn getDeviceGroupPeerMemoryFeatures(
        self: Self,
        heap_index: u32,
        local_device_index: u32,
        remote_device_index: u32,
    ) vk.PeerMemoryFeatureFlags {
        return self.vkd.getDeviceGroupPeerMemoryFeatures(self.handle, heap_index, local_device_index, remote_device_index);
    }

    pub inline fn bindBufferMemory2(
        self: Self,
        bind_info_count: u32,
        p_bind_infos: [*]const vk.BindBufferMemoryInfo,
    ) DeviceDispatch.BindBufferMemory2Error!void {
        return self.vkd.bindBufferMemory2(self.handle, bind_info_count, p_bind_infos);
    }

    pub inline fn bindImageMemory2(
        self: Self,
        bind_info_count: u32,
        p_bind_infos: [*]const vk.BindImageMemoryInfo,
    ) DeviceDispatch.BindImageMemory2Error!void {
        return self.vkd.bindImageMemory2(self.handle, bind_info_count, p_bind_infos);
    }

    pub inline fn cmdSetDeviceMask(
        self: Self,
        command_buffer: vk.CommandBuffer,
        device_mask: u32,
    ) void {
        self.vkd.cmdSetDeviceMask(command_buffer, device_mask);
    }

    pub inline fn getDeviceGroupPresentCapabilitiesKHR(
        self: Self,
        p_device_group_present_capabilities: *vk.DeviceGroupPresentCapabilitiesKHR,
    ) DeviceDispatch.GetDeviceGroupPresentCapabilitiesKHRError!void {
        return self.vkd.getDeviceGroupPresentCapabilitiesKHR(self.handle, p_device_group_present_capabilities);
    }

    pub inline fn getDeviceGroupSurfacePresentModesKHR(
        self: Self,
        surface: vk.SurfaceKHR,
    ) DeviceDispatch.GetDeviceGroupSurfacePresentModesKHRError!vk.DeviceGroupPresentModeFlagsKHR {
        return self.vkd.getDeviceGroupSurfacePresentModesKHR(self.handle, surface);
    }

    pub inline fn acquireNextImage2KHR(
        self: Self,
        p_acquire_info: *const vk.AcquireNextImageInfoKHR,
    ) DeviceDispatch.AcquireNextImage2KHRError!vk.AcquireNextImage2KHRResult {
        return self.vkd.acquireNextImage2KHR(self.handle, p_acquire_info);
    }

    pub inline fn cmdDispatchBase(
        self: Self,
        command_buffer: vk.CommandBuffer,
        base_group_x: u32,
        base_group_y: u32,
        base_group_z: u32,
        group_count_x: u32,
        group_count_y: u32,
        group_count_z: u32,
    ) void {
        self.vkd.cmdDispatchBase(command_buffer, base_group_x, base_group_y, base_group_z, group_count_x, group_count_y, group_count_z);
    }

    pub inline fn createDescriptorUpdateTemplate(
        self: Self,
        p_create_info: *const vk.DescriptorUpdateTemplateCreateInfo,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) DeviceDispatch.CreateDescriptorUpdateTemplateError!vk.DescriptorUpdateTemplate {
        return self.vkd.createDescriptorUpdateTemplate(self.handle, p_create_info, p_allocator);
    }

    pub inline fn destroyDescriptorUpdateTemplate(
        self: Self,
        descriptor_update_template: vk.DescriptorUpdateTemplate,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) void {
        self.vkd.destroyDescriptorUpdateTemplate(self.handle, descriptor_update_template, p_allocator);
    }

    pub inline fn updateDescriptorSetWithTemplate(
        self: Self,
        descriptor_set: vk.DescriptorSet,
        descriptor_update_template: vk.DescriptorUpdateTemplate,
        p_data: *const anyopaque,
    ) void {
        self.vkd.updateDescriptorSetWithTemplate(self.handle, descriptor_set, descriptor_update_template, p_data);
    }

    pub inline fn cmdPushDescriptorSetWithTemplateKHR(
        self: Self,
        command_buffer: vk.CommandBuffer,
        descriptor_update_template: vk.DescriptorUpdateTemplate,
        layout: vk.PipelineLayout,
        set: u32,
        p_data: *const anyopaque,
    ) void {
        self.vkd.cmdPushDescriptorSetKHR(command_buffer, descriptor_update_template, layout, set, p_data);
    }

    pub inline fn setHdrMetadataEXT(
        self: Self,
        swapchain_count: u32,
        p_swapchains: [*]const vk.SwapchainKHR,
        p_metadata: [*]const vk.HdrMetadataEXT,
    ) void {
        self.vkd.setHdrMetadataEXT(self.handle, swapchain_count, p_swapchains, p_metadata);
    }

    pub inline fn getSwapchainStatusKHR(
        self: Self,
        swapchain: vk.SwapchainKHR,
    ) DeviceDispatch.GetSwapchainStatusKHRError!vk.Result {
        return self.vkd.getSwapchainStatusKHR(self.handle, swapchain);
    }

    pub inline fn getRefreshCycleDurationGOOGLE(
        self: Self,
        swapchain: vk.SwapchainKHR,
    ) DeviceDispatch.GetRefreshCycleDurationGOOGLEError!vk.RefreshCycleDurationGOOGLE {
        return self.vkd.getRefreshCycleDurationGOOGLE(self.handle, swapchain);
    }

    pub inline fn getPastPresentationTimingGOOGLE(
        self: Self,
        swapchain: vk.SwapchainKHR,
        p_presentation_timing_count: *u32,
        p_presentation_timings: ?[*]vk.PastPresentationTimingGOOGLE,
    ) DeviceDispatch.GetPastPresentationTimingGOOGLEError!vk.Result {
        return self.vkd.getPastPresentationTimingGOOGLE(self.handle, swapchain, p_presentation_timing_count, p_presentation_timings);
    }

    pub inline fn cmdSetViewportWScalingNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        first_viewport: u32,
        viewport_count: u32,
        p_viewport_w_scalings: [*]const vk.ViewportWScalingNV,
    ) void {
        self.vkd.cmdSetViewportWScalingNV(command_buffer, first_viewport, viewport_count, p_viewport_w_scalings);
    }

    pub inline fn cmdSetDiscardRectangleEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        first_discard_rectangle: u32,
        discard_rectangle_count: u32,
        p_discard_rectangles: [*]const vk.Rect2D,
    ) void {
        self.vkd.cmdSetDiscardRectangleEXT(command_buffer, first_discard_rectangle, discard_rectangle_count, p_discard_rectangles);
    }

    pub inline fn cmdSetSampleLocationsEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_sample_locations_info: *const vk.SampleLocationsInfoEXT,
    ) void {
        self.vkd.cmdSetSampleLocationsEXT(command_buffer, p_sample_locations_info);
    }

    pub inline fn getBufferMemoryRequirements2(
        self: Self,
        p_info: *const vk.BufferMemoryRequirementsInfo2,
        p_memory_requirements: *vk.MemoryRequirements2,
    ) void {
        self.vkd.getBufferMemoryRequirements2(self.handle, p_info, p_memory_requirements);
    }

    pub inline fn getImageMemoryRequirements2(
        self: Self,
        p_info: *const vk.ImageMemoryRequirementsInfo2,
        p_memory_requirements: *vk.MemoryRequirements2,
    ) void {
        self.vkd.getImageMemoryRequirements2(self.handle, p_info, p_memory_requirements);
    }

    pub inline fn getImageSparseMemoryRequirements2(
        self: Self,
        p_info: *const vk.ImageSparseMemoryRequirementsInfo2,
        p_sparse_memory_requirement_count: *u32,
        p_sparse_memory_requirements: ?[*]vk.SparseImageMemoryRequirements2,
    ) void {
        self.vkd.getImageSparseMemoryRequirements2(self.handle, p_info, p_sparse_memory_requirement_count, p_sparse_memory_requirements);
    }

    pub inline fn getDeviceBufferMemoryRequirements(
        self: Self,
        p_info: *const vk.DeviceBufferMemoryRequirements,
        p_memory_requirements: *vk.MemoryRequirements2,
    ) void {
        self.vkd.getDeviceBufferMemoryRequirements(self.handle, p_info, p_memory_requirements);
    }

    pub inline fn getDeviceImageMemoryRequirements(
        self: Self,
        p_info: *const vk.DeviceImageMemoryRequirements,
        p_memory_requirements: *vk.MemoryRequirements2,
    ) void {
        self.vkd.getDeviceImageMemoryRequirements(self.handle, p_info, p_memory_requirements);
    }

    pub inline fn getDeviceImageSparseMemoryRequirements(
        self: Self,
        p_info: *const vk.DeviceImageMemoryRequirements,
        p_sparse_memory_requirement_count: *u32,
        p_sparse_memory_requirements: ?[*]vk.SparseImageMemoryRequirements2,
    ) void {
        self.vkd.getDeviceImageSparseMemoryRequirements(self.handle, p_info, p_sparse_memory_requirement_count, p_sparse_memory_requirements);
    }

    pub inline fn createSamplerYcbcrConversion(
        self: Self,
        p_create_info: *const vk.SamplerYcbcrConversionCreateInfo,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) DeviceDispatch.CreateSamplerYcbcrConversionError!vk.SamplerYcbcrConversion {
        return self.vkd.createSamplerYcbcrConversion(self.handle, p_create_info, p_allocator);
    }

    pub inline fn destroySamplerYcbcrConversion(
        self: Self,
        ycbcr_conversion: vk.SamplerYcbcrConversion,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) void {
        self.vkd.destroySamplerYcbcrConversion(self.handle, ycbcr_conversion, p_allocator);
    }

    pub inline fn getDeviceQueue2(
        self: Self,
        p_queue_info: *const vk.DeviceQueueInfo2,
    ) vk.Queue {
        return self.vkd.getDeviceQueue2(self.handle, p_queue_info);
    }

    pub inline fn createValidationCacheEXT(
        self: Self,
        p_create_info: *const vk.ValidationCacheCreateInfoEXT,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) DeviceDispatch.CreateValidationCacheEXTError!vk.ValidationCacheEXT {
        return self.vkd.createValidationCacheEXT(self.handle, p_create_info, p_allocator);
    }

    pub inline fn destroyValidationCacheEXT(
        self: Self,
        validation_cache: vk.ValidationCacheEXT,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) void {
        self.vkd.destroyValidationCacheEXT(self.handle, validation_cache, p_allocator);
    }

    pub inline fn getValidationCacheDataEXT(
        self: Self,
        validation_cache: vk.ValidationCacheEXT,
        p_data_size: *usize,
        p_data: ?*anyopaque,
    ) DeviceDispatch.GetValidationCacheDataEXTError!vk.Result {
        return self.vkd.getValidationCacheDataEXT(self.handle, validation_cache, p_data_size, p_data);
    }

    pub inline fn mergeValidationCachesEXT(
        self: Self,
        dst_cache: vk.ValidationCacheEXT,
        src_cache_count: u32,
        p_src_caches: [*]const vk.ValidationCacheEXT,
    ) DeviceDispatch.MergeValidationCachesEXTError!void {
        return self.vkd.mergeValidationCachesEXT(self.handle, dst_cache, src_cache_count, p_src_caches);
    }

    pub inline fn getDescriptorSetLayoutSupport(
        self: Self,
        p_create_info: *const vk.DescriptorSetLayoutCreateInfo,
        p_support: *vk.DescriptorSetLayoutSupport,
    ) void {
        self.vkd.getDescriptorSetLayoutSupport(self.handle, p_create_info, p_support);
    }

    pub inline fn getSwapchainGrallocUsageANDROID(
        self: Self,
        format: vk.Format,
        image_usage: vk.ImageUsageFlags,
    ) DeviceDispatch.GetSwapchainGrallocUsageANDROIDError!c_int {
        return self.vkd.getSwapchainGrallocUsageANDROID(self.handle, format, image_usage);
    }

    pub inline fn getSwapchainGrallocUsage2ANDROID(
        self: Self,
        format: vk.Format,
        image_usage: vk.ImageUsageFlags,
        swapchain_image_usage: vk.SwapchainImageUsageFlagsANDROID,
    ) DeviceDispatch.GetSwapchainGrallocUsage2ANDROIDError!vk.GetSwapchainGrallocUsage2ANDROIDResult {
        return self.vkd.getSwapchainGrallocUsage2ANDROID(self.handle, format, image_usage, swapchain_image_usage);
    }

    pub inline fn acquireImageANDROID(
        self: Self,
        image: vk.Image,
        native_fence_fd: c_int,
        semaphore: vk.Semaphore,
        fence: vk.Fence,
    ) DeviceDispatch.AcquireImageANDROIDError!void {
        return self.vkd.acquireImageANDROID(self.handle, image, native_fence_fd, semaphore, fence);
    }

    pub inline fn queueSignalReleaseImageANDROID(
        self: Self,
        queue: vk.Queue,
        wait_semaphore_count: u32,
        p_wait_semaphores: [*]const vk.Semaphore,
        image: vk.Image,
    ) DeviceDispatch.QueueSignalReleaseImageANDROIDError!c_int {
        return self.vkd.queueSignalReleaseImageANDROID(queue, wait_semaphore_count, p_wait_semaphores, image);
    }

    pub inline fn getShaderInfoAMD(
        self: Self,
        pipeline: vk.Pipeline,
        shader_stage: vk.ShaderStageFlags,
        info_type: vk.ShaderInfoTypeAMD,
        p_info_size: *usize,
        p_info: ?*anyopaque,
    ) DeviceDispatch.GetShaderInfoAMDError!vk.Result {
        return self.vkd.getShaderInfoAMD(self.handle, pipeline, shader_stage, info_type, p_info_size, p_info);
    }

    pub inline fn setLocalDimmingAMD(
        self: Self,
        swap_chain: vk.SwapchainKHR,
        local_dimming_enable: vk.Bool32,
    ) void {
        self.vkd.setLocalDimmingAMD(self.handle, swap_chain, local_dimming_enable);
    }

    pub inline fn getCalibratedTimestampsEXT(
        self: Self,
        timestamp_count: u32,
        p_timestamp_infos: [*]const vk.CalibratedTimestampInfoEXT,
        p_timestamps: [*]u64,
    ) DeviceDispatch.GetCalibratedTimestampsEXTError!u64 {
        return self.vkd.getCalibratedTimestampsEXT(self.handle, timestamp_count, p_timestamp_infos, p_timestamps);
    }

    pub inline fn setDebugUtilsObjectNameEXT(
        self: Self,
        p_name_info: *const vk.DebugUtilsObjectNameInfoEXT,
    ) DeviceDispatch.SetDebugUtilsObjectNameEXTError!void {
        return self.vkd.setDebugUtilsObjectNameEXT(self.handle, p_name_info);
    }

    pub inline fn setDebugUtilsObjectTagEXT(
        self: Self,
        p_tag_info: *const vk.DebugUtilsObjectTagInfoEXT,
    ) DeviceDispatch.SetDebugUtilsObjectTagEXTError!void {
        return self.vkd.setDebugUtilsObjectTagEXT(self.handle, p_tag_info);
    }

    pub inline fn queueBeginDebugUtilsLabelEXT(
        self: Self,
        queue: vk.Queue,
        p_label_info: *const vk.DebugUtilsLabelEXT,
    ) void {
        self.vkd.queueBeginDebugUtilsLabelEXT(queue, p_label_info);
    }

    pub inline fn queueEndDebugUtilsLabelEXT(
        self: Self,
        queue: vk.Queue,
    ) void {
        self.vkd.queueEndDebugUtilsLabelEXT(queue);
    }

    pub inline fn queueInsertDebugUtilsLabelEXT(
        self: Self,
        queue: vk.Queue,
        p_label_info: *const vk.DebugUtilsLabelEXT,
    ) void {
        self.vkd.queueInsertDebugUtilsLabelEXT(queue, p_label_info);
    }

    pub inline fn cmdBeginDebugUtilsLabelEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_label_info: *const vk.DebugUtilsLabelEXT,
    ) void {
        self.vkd.cmdBeginDebugUtilsLabelEXT(command_buffer, p_label_info);
    }

    pub inline fn cmdEndDebugUtilsLabelEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
    ) void {
        self.vkd.cmdEndDebugUtilsLabelEXT(command_buffer);
    }

    pub inline fn cmdInsertDebugUtilsLabelEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_label_info: *const vk.DebugUtilsLabelEXT,
    ) void {
        self.vkd.cmdInsertDebugUtilsLabelEXT(command_buffer, p_label_info);
    }

    pub inline fn getMemoryHostPointerPropertiesEXT(
        self: Self,
        handle_type: vk.ExternalMemoryHandleTypeFlags,
        p_host_pointer: *const anyopaque,
        p_memory_host_pointer_properties: *vk.MemoryHostPointerPropertiesEXT,
    ) DeviceDispatch.GetMemoryHostPointerPropertiesEXTError!void {
        self.vkd.getMemoryHostPointerPropertiesEXT(self.handle, handle_type, p_host_pointer, p_memory_host_pointer_properties);
    }

    pub inline fn cmdWriteBufferMarkerAMD(
        self: Self,
        command_buffer: vk.CommandBuffer,
        pipeline_stage: vk.PipelineStageFlags,
        dst_buffer: vk.Buffer,
        dst_offset: vk.DeviceSize,
        marker: u32,
    ) void {
        self.vkd.cmdWriteBufferMarkerAMD(
            command_buffer,
            pipeline_stage,
            dst_buffer,
            dst_offset,
            marker,
        );
    }

    pub inline fn createRenderPass2(
        self: Self,
        p_create_info: *const vk.RenderPassCreateInfo2,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) DeviceDispatch.CreateRenderPass2Error!vk.RenderPass {
        return self.vkd.createRenderPass2(self.handle, p_create_info, p_allocator);
    }

    pub inline fn cmdBeginRenderPass2(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_render_pass_begin: *const vk.RenderPassBeginInfo,
        p_subpass_begin_info: *const vk.SubpassBeginInfo,
    ) void {
        self.vkd.cmdBeginRenderPass2(command_buffer, p_render_pass_begin, p_subpass_begin_info);
    }

    pub inline fn cmdNextSubpass2(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_subpass_begin_info: *const vk.SubpassBeginInfo,
        p_subpass_end_info: *const vk.SubpassEndInfo,
    ) void {
        self.vkd.cmdNextSubpass2(command_buffer, p_subpass_begin_info, p_subpass_end_info);
    }

    pub inline fn cmdEndRenderPass2(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_subpass_end_info: *const vk.SubpassEndInfo,
    ) void {
        self.vkd.cmdEndRenderPass2(command_buffer, p_subpass_end_info);
    }

    pub inline fn getSemaphoreCounterValue(
        self: Self,
        semaphore: vk.Semaphore,
    ) DeviceDispatch.GetSemaphoreCounterValueError!u64 {
        return self.vkd.getSemaphoreCounterValue(self.handle, semaphore);
    }

    pub inline fn waitSemaphores(
        self: Self,
        p_wait_info: *const vk.SemaphoreWaitInfo,
        timeout: u64,
    ) DeviceDispatch.WaitSemaphoresError!vk.Result {
        return self.vkd.waitSemaphores(self.handle, p_wait_info, timeout);
    }

    pub inline fn signalSemaphore(
        self: Self,
        p_signal_info: *const vk.SemaphoreSignalInfo,
    ) DeviceDispatch.SignalSemaphoreError!void {
        return self.vkd.signalSemaphore(self.handle, p_signal_info);
    }

    pub inline fn getAndroidHardwareBufferPropertiesANDROID(
        self: Self,
        buffer: *const vk.AHardwareBuffer,
        p_properties: *vk.AndroidHardwareBufferPropertiesANDROID,
    ) DeviceDispatch.GetAndroidHardwareBufferPropertiesANDROIDError!void {
        return self.vkd.getAndroidHardwareBufferPropertiesANDROID(self.handle, buffer, p_properties);
    }

    pub inline fn getMemoryAndroidHardwareBufferANDROID(
        self: Self,
        p_info: *const vk.MemoryGetAndroidHardwareBufferInfoANDROID,
    ) DeviceDispatch.GetMemoryAndroidHardwareBufferANDROIDError!*vk.AHardwareBuffer {
        return self.vkd.getMemoryAndroidHardwareBufferANDROID(self.handle, p_info);
    }

    pub inline fn cmdDrawIndirectCount(
        self: Self,
        command_buffer: vk.CommandBuffer,
        buffer: vk.Buffer,
        offset: vk.DeviceSize,
        count_buffer: vk.Buffer,
        count_buffer_offset: vk.DeviceSize,
        max_draw_count: u32,
        stride: u32,
    ) void {
        self.vkd.cmdDrawIndirectCount(command_buffer, buffer, offset, count_buffer, count_buffer_offset, max_draw_count, stride);
    }

    pub inline fn cmdDrawIndexedIndirectCount(
        self: Self,
        command_buffer: vk.CommandBuffer,
        buffer: vk.Buffer,
        offset: vk.DeviceSize,
        count_buffer: vk.Buffer,
        count_buffer_offset: vk.DeviceSize,
        max_draw_count: u32,
        stride: u32,
    ) void {
        self.vkd.cmdDrawIndexedIndirectCount(
            command_buffer,
            buffer,
            offset,
            count_buffer,
            count_buffer_offset,
            max_draw_count,
            stride,
        );
    }

    pub inline fn cmdSetCheckpointNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_checkpoint_marker: *const anyopaque,
    ) void {
        self.vkd.cmdSetCheckpointNV(command_buffer, p_checkpoint_marker);
    }

    pub inline fn getQueueCheckpointDataNV(
        self: Self,
        queue: vk.Queue,
        p_checkpoint_data_count: *u32,
        p_checkpoint_data: ?[*]vk.CheckpointDataNV,
    ) void {
        self.vkd.getQueueCheckpointDataNV(queue, p_checkpoint_data_count, p_checkpoint_data);
    }

    pub inline fn cmdBindTransformFeedbackBuffersEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        first_binding: u32,
        binding_count: u32,
        p_buffers: [*]const vk.Buffer,
        p_offsets: [*]const vk.DeviceSize,
        p_sizes: ?[*]const vk.DeviceSize,
    ) void {
        self.vkd.cmdBindTransformFeedbackBuffersEXT(command_buffer, first_binding, binding_count, p_buffers, p_offsets, p_sizes);
    }

    pub inline fn cmdBeginTransformFeedbackEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        first_counter_buffer: u32,
        counter_buffer_count: u32,
        p_counter_buffers: [*]const vk.Buffer,
        p_counter_buffer_offsets: ?[*]const vk.DeviceSize,
    ) void {
        self.vkd.cmdBeginTransformFeedbackEXT(command_buffer, first_counter_buffer, counter_buffer_count, p_counter_buffers, p_counter_buffer_offsets);
    }

    pub inline fn cmdEndTransformFeedbackEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        first_counter_buffer: u32,
        counter_buffer_count: u32,
        p_counter_buffers: [*]const vk.Buffer,
        p_counter_buffer_offsets: ?[*]const vk.DeviceSize,
    ) void {
        self.vkd.cmdEndTransformFeedbackEXT(command_buffer, first_counter_buffer, counter_buffer_count, p_counter_buffers, p_counter_buffer_offsets);
    }

    pub inline fn cmdBeginQueryIndexedEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        query_pool: vk.QueryPool,
        query: u32,
        flags: vk.QueryControlFlags,
        index: u32,
    ) void {
        self.vkd.cmdBeginQueryIndexedEXT(command_buffer, query_pool, query, flags, index);
    }

    pub inline fn cmdEndQueryIndexedEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        query_pool: vk.QueryPool,
        query: u32,
        index: u32,
    ) void {
        self.vkd.cmdEndQueryIndexedEXT(command_buffer, query_pool, query, index);
    }

    pub inline fn cmdDrawIndirectByteCountEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        instance_count: u32,
        first_instance: u32,
        counter_buffer: vk.Buffer,
        counter_buffer_offset: vk.DeviceSize,
        counter_offset: u32,
        vertex_stride: u32,
    ) void {
        self.vkd.cmdDrawIndirectByteCountEXT(command_buffer, instance_count, first_instance, counter_buffer, counter_buffer_offset, counter_offset, vertex_stride);
    }
    pub inline fn cmdSetExclusiveScissorNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        first_exclusive_scissor: u32,
        exclusive_scissor_count: u32,
        p_exclusive_scissors: [*]const vk.Rect2D,
    ) void {
        self.vkd.cmdSetExclusiveScissorNV(command_buffer, first_exclusive_scissor, exclusive_scissor_count, p_exclusive_scissors);
    }

    pub inline fn cmdBindShadingRateImageNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        image_view: vk.ImageView,
        image_layout: vk.ImageLayout,
    ) void {
        self.vkd.cmdBindShadingRateImageNV(command_buffer, image_view, image_layout);
    }

    pub inline fn cmdSetViewportShadingRatePaletteNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        first_viewport: u32,
        viewport_count: u32,
        p_shading_rate_palettes: [*]const vk.ShadingRatePaletteNV,
    ) void {
        self.vkd.cmdSetViewportShadingRatePaletteNV(command_buffer, first_viewport, viewport_count, p_shading_rate_palettes);
    }

    pub inline fn cmdSetCoarseSampleOrderNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        sample_order_type: vk.CoarseSampleOrderTypeNV,
        custom_sample_order_count: u32,
        p_custom_sample_orders: [*]const vk.CoarseSampleOrderCustomNV,
    ) void {
        self.vkd.cmdSetCoarseSampleOrderNV(command_buffer, sample_order_type, custom_sample_order_count, p_custom_sample_orders);
    }

    pub inline fn cmdDrawMeshTasksNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        task_count: u32,
        first_task: u32,
    ) void {
        self.vkd.cmdDrawMeshTasksNV(command_buffer, task_count, first_task);
    }

    pub inline fn cmdDrawMeshTasksIndirectNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        buffer: vk.Buffer,
        offset: vk.DeviceSize,
        draw_count: u32,
        stride: u32,
    ) void {
        self.vkd.cmdDrawMeshTasksIndirectNV(command_buffer, buffer, offset, draw_count, stride);
    }

    pub inline fn cmdDrawMeshTasksIndirectCountNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        buffer: vk.Buffer,
        offset: vk.DeviceSize,
        count_buffer: vk.Buffer,
        count_buffer_offset: vk.DeviceSize,
        max_draw_count: u32,
        stride: u32,
    ) void {
        self.vkd.cmdDrawMeshTasksIndirectCountNV(command_buffer, buffer, offset, count_buffer, count_buffer_offset, max_draw_count, stride);
    }

    pub inline fn cmdDrawMeshTasksEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        group_count_x: u32,
        group_count_y: u32,
        group_count_z: u32,
    ) void {
        self.vkd.cmdDrawMeshTasksEXT(command_buffer, group_count_x, group_count_y, group_count_z);
    }

    pub inline fn cmdDrawMeshTasksIndirectEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        buffer: vk.Buffer,
        offset: vk.DeviceSize,
        draw_count: u32,
        stride: u32,
    ) void {
        self.vkd.cmdDrawMeshTasksIndirectEXT(command_buffer, buffer, offset, draw_count, stride);
    }

    pub inline fn cmdDrawMeshTasksIndirectCountEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        buffer: vk.Buffer,
        offset: vk.DeviceSize,
        count_buffer: vk.Buffer,
        count_buffer_offset: vk.DeviceSize,
        max_draw_count: u32,
        stride: u32,
    ) void {
        self.vkd.cmdDrawMeshTasksIndirectCountEXT(command_buffer, buffer, offset, count_buffer, count_buffer_offset, max_draw_count, stride);
    }

    pub inline fn compileDeferredNV(
        self: Self,
        pipeline: vk.Pipeline,
        shader: u32,
    ) DeviceDispatch.CompileDeferredNVError!void {
        return self.vkd.compileDeferredNV(self.handle, pipeline, shader);
    }

    pub inline fn createAccelerationStructureNV(
        self: Self,
        p_create_info: *const vk.AccelerationStructureCreateInfoNV,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) DeviceDispatch.CreateAccelerationStructureNVError!vk.AccelerationStructureNV {
        return self.vkd.createAccelerationStructureNV(self.handle, p_create_info, p_allocator);
    }

    pub inline fn cmdBindInvocationMaskHUAWEI(
        self: Self,
        command_buffer: vk.CommandBuffer,
        image_view: vk.ImageView,
        image_layout: vk.ImageLayout,
    ) void {
        self.vkd.cmdBindInvocationMaskHUAWEI(command_buffer, image_view, image_layout);
    }

    pub inline fn destroyAccelerationStructureKHR(
        self: Self,
        acceleration_structure: vk.AccelerationStructureKHR,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) void {
        self.vkd.destroyAccelerationStructureKHR(self.handle, acceleration_structure, p_allocator);
    }

    pub inline fn destroyAccelerationStructureNV(
        self: Self,
        acceleration_structure: vk.AccelerationStructureNV,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) void {
        self.vkd.destroyAccelerationStructureNV(self.handle, acceleration_structure, p_allocator);
    }

    pub inline fn getAccelerationStructureMemoryRequirementsNV(
        self: Self,
        p_info: *const vk.AccelerationStructureMemoryRequirementsInfoNV,
        p_memory_requirements: *vk.MemoryRequirements2KHR,
    ) void {
        self.vkd.getAccelerationStructureMemoryRequirementsNV(self.handle, p_info, p_memory_requirements);
    }

    pub inline fn bindAccelerationStructureMemoryNV(
        self: Self,
        bind_info_count: u32,
        p_bind_infos: [*]const vk.BindAccelerationStructureMemoryInfoNV,
    ) DeviceDispatch.BindAccelerationStructureMemoryNVError!void {
        self.vkd.bindAccelerationStructureMemoryNV(self.handle, bind_info_count, p_bind_infos);
    }

    pub inline fn cmdCopyAccelerationStructureNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        dst: vk.AccelerationStructureNV,
        src: vk.AccelerationStructureNV,
        mode: vk.CopyAccelerationStructureModeKHR,
    ) void {
        self.vkd.cmdCopyAccelerationStructureNV(command_buffer, dst, src, mode);
    }

    pub inline fn cmdCopyAccelerationStructureKHR(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_info: *const vk.CopyAccelerationStructureInfoKHR,
    ) void {
        self.vkd.cmdCopyAccelerationStructureKHR(command_buffer, p_info);
    }

    pub inline fn copyAccelerationStructureKHR(
        self: Self,
        deferred_operation: vk.DeferredOperationKHR,
        p_info: *const vk.CopyAccelerationStructureInfoKHR,
    ) DeviceDispatch.CopyAccelerationStructureKHRError!vk.Result {
        return self.vkd.copyAccelerationStructureKHR(self.handle, deferred_operation, p_info);
    }

    pub inline fn cmdCopyAccelerationStructureToMemoryKHR(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_info: *const vk.CopyAccelerationStructureToMemoryInfoKHR,
    ) void {
        self.vkd.cmdCopyAccelerationStructureKHR(command_buffer, p_info);
    }

    pub inline fn copyAccelerationStructureToMemoryKHR(
        self: Self,
        deferred_operation: vk.DeferredOperationKHR,
        p_info: *const vk.CopyAccelerationStructureToMemoryInfoKHR,
    ) DeviceDispatch.CopyAccelerationStructureToMemoryKHRError!vk.Result {
        return self.vkd.copyAccelerationStructureToMemoryKHR(self.handle, deferred_operation, p_info);
    }

    pub inline fn cmdCopyMemoryToAccelerationStructureKHR(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_info: *const vk.CopyMemoryToAccelerationStructureInfoKHR,
    ) void {
        self.vkd.cmdCopyMemoryToAccelerationStructureKHR(command_buffer, p_info);
    }

    pub inline fn copyMemoryToAccelerationStructureKHR(
        self: Self,
        deferred_operation: vk.DeferredOperationKHR,
        p_info: *const vk.CopyMemoryToAccelerationStructureInfoKHR,
    ) DeviceDispatch.CopyMemoryToAccelerationStructureKHRError!vk.Result {
        return self.vkd.copyMemoryToAccelerationStructureKHR(self.handle, deferred_operation, p_info);
    }

    pub inline fn cmdWriteAccelerationStructuresPropertiesKHR(
        self: Self,
        command_buffer: vk.CommandBuffer,
        acceleration_structure_count: u32,
        p_acceleration_structures: [*]const vk.AccelerationStructureKHR,
        query_type: vk.QueryType,
        query_pool: vk.QueryPool,
        first_query: u32,
    ) void {
        self.vkd.cmdWriteAccelerationStructuresPropertiesKHR(command_buffer, acceleration_structure_count, p_acceleration_structures, query_type, query_pool, first_query);
    }

    pub inline fn cmdWriteAccelerationStructuresPropertiesNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        acceleration_structure_count: u32,
        p_acceleration_structures: [*]const vk.AccelerationStructureNV,
        query_type: vk.QueryType,
        query_pool: vk.QueryPool,
        first_query: u32,
    ) void {
        self.vkd.cmdWriteAccelerationStructuresPropertiesNV(
            command_buffer,
            acceleration_structure_count,
            p_acceleration_structures,
            query_type,
            query_pool,
            first_query,
        );
    }

    pub inline fn cmdBuildAccelerationStructureNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_info: *const vk.AccelerationStructureInfoNV,
        instance_data: vk.Buffer,
        instance_offset: vk.DeviceSize,
        update: vk.Bool32,
        dst: vk.AccelerationStructureNV,
        src: vk.AccelerationStructureNV,
        scratch: vk.Buffer,
        scratch_offset: vk.DeviceSize,
    ) void {
        self.vkd.cmdBuildAccelerationStructureNV(command_buffer, p_info, instance_data, instance_offset, update, dst, src, scratch, scratch_offset);
    }

    pub inline fn writeAccelerationStructuresPropertiesKHR(
        self: Self,
        acceleration_structure_count: u32,
        p_acceleration_structures: [*]const vk.AccelerationStructureKHR,
        query_type: vk.QueryType,
        data_size: usize,
        p_data: *anyopaque,
        stride: usize,
    ) DeviceDispatch.WriteAccelerationStructuresPropertiesKHRError!void {
        return self.vkd.writeAccelerationStructuresPropertiesKHR(self.handle, acceleration_structure_count, p_acceleration_structures, query_type, data_size, p_data, stride);
    }

    pub inline fn cmdTraceRaysKHR(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_raygen_shader_binding_table: *const vk.StridedDeviceAddressRegionKHR,
        p_miss_shader_binding_table: *const vk.StridedDeviceAddressRegionKHR,
        p_hit_shader_binding_table: *const vk.StridedDeviceAddressRegionKHR,
        p_callable_shader_binding_table: *const vk.StridedDeviceAddressRegionKHR,
        width: u32,
        height: u32,
        depth: u32,
    ) void {
        self.vkd.cmdTraceRaysKHR(command_buffer, p_raygen_shader_binding_table, p_miss_shader_binding_table, p_hit_shader_binding_table, p_callable_shader_binding_table, width, height, depth);
    }

    pub inline fn cmdTraceRaysNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        raygen_shader_binding_table_buffer: vk.Buffer,
        raygen_shader_binding_offset: vk.DeviceSize,
        miss_shader_binding_table_buffer: vk.Buffer,
        miss_shader_binding_offset: vk.DeviceSize,
        miss_shader_binding_stride: vk.DeviceSize,
        hit_shader_binding_table_buffer: vk.Buffer,
        hit_shader_binding_offset: vk.DeviceSize,
        hit_shader_binding_stride: vk.DeviceSize,
        callable_shader_binding_table_buffer: vk.Buffer,
        callable_shader_binding_offset: vk.DeviceSize,
        callable_shader_binding_stride: vk.DeviceSize,
        width: u32,
        height: u32,
        depth: u32,
    ) void {
        self.vkd.cmdTraceRaysNV(
            command_buffer,
            raygen_shader_binding_table_buffer,
            raygen_shader_binding_offset,
            miss_shader_binding_table_buffer,
            miss_shader_binding_offset,
            miss_shader_binding_stride,
            hit_shader_binding_table_buffer,
            hit_shader_binding_offset,
            hit_shader_binding_stride,
            callable_shader_binding_table_buffer,
            callable_shader_binding_offset,
            callable_shader_binding_stride,
            width,
            height,
            depth,
        );
    }

    pub inline fn getRayTracingShaderGroupHandlesKHR(
        self: Self,
        pipeline: vk.Pipeline,
        first_group: u32,
        group_count: u32,
        data_size: usize,
        p_data: *anyopaque,
    ) DeviceDispatch.GetRayTracingShaderGroupHandlesKHRError!void {
        return self.vkd.getRayTracingShaderGroupHandlesKHR(self.handle, pipeline, first_group, group_count, data_size, p_data);
    }

    pub inline fn getRayTracingCaptureReplayShaderGroupHandlesKHR(
        self: Self,
        pipeline: vk.Pipeline,
        first_group: u32,
        group_count: u32,
        data_size: usize,
        p_data: *anyopaque,
    ) DeviceDispatch.GetRayTracingCaptureReplayShaderGroupHandlesKHRError!void {
        return self.vkd.getRayTracingCaptureReplayShaderGroupHandlesKHR(self.handle, pipeline, first_group, group_count, data_size, p_data);
    }

    pub inline fn getAccelerationStructureHandleNV(
        self: Self,
        acceleration_structure: vk.AccelerationStructureNV,
        data_size: usize,
        p_data: *anyopaque,
    ) DeviceDispatch.GetAccelerationStructureHandleNVError!void {
        return self.vkd.getAccelerationStructureHandleNV(self.handle, acceleration_structure, data_size, p_data);
    }

    pub inline fn createRayTracingPipelinesNV(
        self: Self,
        pipeline_cache: vk.PipelineCache,
        create_info_count: u32,
        p_create_infos: [*]const vk.RayTracingPipelineCreateInfoNV,
        p_allocator: ?*const vk.AllocationCallbacks,
        p_pipelines: [*]vk.Pipeline,
    ) DeviceDispatch.CreateRayTracingPipelinesNVError!vk.Result {
        return self.vkd.createRayTracingPipelinesNV(self.handle, pipeline_cache, create_info_count, p_create_infos, p_allocator, p_pipelines);
    }

    pub inline fn createRayTracingPipelinesKHR(
        self: Self,
        deferred_operation: vk.DeferredOperationKHR,
        pipeline_cache: vk.PipelineCache,
        create_info_count: u32,
        p_create_infos: [*]const vk.RayTracingPipelineCreateInfoKHR,
        p_allocator: ?*const vk.AllocationCallbacks,
        p_pipelines: [*]vk.Pipeline,
    ) DeviceDispatch.CreateRayTracingPipelinesKHRError!vk.Result {
        return self.vkd.createRayTracingPipelinesKHR(self.handle, deferred_operation, pipeline_cache, create_info_count, p_create_infos, p_allocator, p_pipelines);
    }

    pub inline fn cmdTraceRaysIndirectKHR(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_raygen_shader_binding_table: *const vk.StridedDeviceAddressRegionKHR,
        p_miss_shader_binding_table: *const vk.StridedDeviceAddressRegionKHR,
        p_hit_shader_binding_table: *const vk.StridedDeviceAddressRegionKHR,
        p_callable_shader_binding_table: *const vk.StridedDeviceAddressRegionKHR,
        indirect_device_address: vk.DeviceAddress,
    ) void {
        self.vkd.cmdTraceRaysIndirectKHR(command_buffer, p_raygen_shader_binding_table, p_miss_shader_binding_table, p_hit_shader_binding_table, p_callable_shader_binding_table, indirect_device_address);
    }

    pub inline fn cmdTraceRaysIndirect2KHR(
        self: Self,
        command_buffer: vk.CommandBuffer,
        indirect_device_address: vk.DeviceAddress,
    ) void {
        self.vkd.cmdTraceRaysIndirect2KHR(command_buffer, indirect_device_address);
    }

    pub inline fn getDeviceAccelerationStructureCompatibilityKHR(
        self: Self,
        p_version_info: *const vk.AccelerationStructureVersionInfoKHR,
    ) vk.AccelerationStructureCompatibilityKHR {
        return self.vkd.getDeviceAccelerationStructureCompatibilityKHR(self.handle, p_version_info);
    }

    pub inline fn getRayTracingShaderGroupStackSizeKHR(
        self: Self,
        pipeline: vk.Pipeline,
        group: u32,
        group_shader: vk.ShaderGroupShaderKHR,
    ) vk.DeviceSize {
        return self.vkd.getRayTracingShaderGroupStackSizeKHR(self.handle, pipeline, group, group_shader);
    }

    pub inline fn cmdSetRayTracingPipelineStackSizeKHR(
        self: Self,
        command_buffer: vk.CommandBuffer,
        pipeline_stack_size: u32,
    ) void {
        self.vkd.cmdSetRayTracingPipelineStackSizeKHR(command_buffer, pipeline_stack_size);
    }

    pub inline fn getImageViewHandleNVX(
        self: Self,
        p_info: *const vk.ImageViewHandleInfoNVX,
    ) u32 {
        return self.vkd.getImageViewHandleNVX(self.handle, p_info);
    }

    pub inline fn getImageViewAddressNVX(
        self: Self,
        image_view: vk.ImageView,
        p_properties: *vk.ImageViewAddressPropertiesNVX,
    ) DeviceDispatch.GetImageViewAddressNVXError!void {
        return self.vkd.getImageViewAddressNVX(self.handle, image_view, p_properties);
    }

    pub inline fn getDeviceGroupSurfacePresentModes2EXT(
        self: Self,
        p_surface_info: *const vk.PhysicalDeviceSurfaceInfo2KHR,
    ) DeviceDispatch.GetDeviceGroupSurfacePresentModes2EXTError!vk.DeviceGroupPresentModeFlagsKHR {
        return self.vkd.getDeviceGroupSurfacePresentModes2EXT(self.handle, p_surface_info);
    }

    pub inline fn acquireFullScreenExclusiveModeEXT(
        self: Self,
        swapchain: vk.SwapchainKHR,
    ) DeviceDispatch.AcquireFullScreenExclusiveModeEXTError!void {
        return self.vkd.acquireFullScreenExclusiveModeEXT(self.handle, swapchain);
    }

    pub inline fn releaseFullScreenExclusiveModeEXT(
        self: Self,
        swapchain: vk.SwapchainKHR,
    ) DeviceDispatch.ReleaseFullScreenExclusiveModeEXTError!void {
        return self.vkd.releaseFullScreenExclusiveModeEXT(self.handle, swapchain);
    }

    pub inline fn acquireProfilingLockKHR(
        self: Self,
        p_info: *const vk.AcquireProfilingLockInfoKHR,
    ) DeviceDispatch.AcquireProfilingLockKHRError!void {
        self.vkd.acquireProfilingLockKHR(self.handle, p_info);
    }

    pub inline fn releaseProfilingLockKHR(
        self: Self,
    ) void {
        self.vkd.releaseProfilingLockKHR(self.handle);
    }

    pub inline fn getImageDrmFormatModifierPropertiesEXT(
        self: Self,
        image: vk.Image,
        p_properties: *vk.ImageDrmFormatModifierPropertiesEXT,
    ) DeviceDispatch.GetImageDrmFormatModifierPropertiesEXTError!void {
        self.vkd.getImageDrmFormatModifierPropertiesEXT(self.handle, image, p_properties);
    }

    pub inline fn getBufferOpaqueCaptureAddress(
        self: Self,
        p_info: *const vk.BufferDeviceAddressInfo,
    ) u64 {
        return self.vkd.getBufferOpaqueCaptureAddress(self.handle, p_info);
    }

    pub inline fn getBufferDeviceAddress(
        self: Self,
        p_info: *const vk.BufferDeviceAddressInfo,
    ) vk.DeviceAddress {
        return self.vkd.getBufferDeviceAddress(self.handle, p_info);
    }

    pub inline fn initializePerformanceApiINTEL(
        self: Self,
        p_initialize_info: *const vk.InitializePerformanceApiInfoINTEL,
    ) DeviceDispatch.InitializePerformanceApiINTELError!void {
        self.vkd.initializePerformanceApiINTEL(self.handle, p_initialize_info);
    }

    pub inline fn uninitializePerformanceApiINTEL(
        self: Self,
    ) void {
        self.vkd.uninitializePerformanceApiINTEL(self.handle);
    }

    pub inline fn cmdSetPerformanceMarkerINTEL(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_marker_info: *const vk.PerformanceMarkerInfoINTEL,
    ) DeviceDispatch.CmdSetPerformanceMarkerINTELError!void {
        return self.vkd.cmdSetPerformanceMarkerINTEL(command_buffer, p_marker_info);
    }

    pub inline fn cmdSetPerformanceStreamMarkerINTEL(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_marker_info: *const vk.PerformanceStreamMarkerInfoINTEL,
    ) DeviceDispatch.CmdSetPerformanceStreamMarkerINTELError!void {
        return self.vkd.cmdSetPerformanceStreamMarkerINTEL(command_buffer, p_marker_info);
    }

    pub inline fn cmdSetPerformanceOverrideINTEL(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_override_info: *const vk.PerformanceOverrideInfoINTEL,
    ) DeviceDispatch.CmdSetPerformanceOverrideINTELError!void {
        return self.vkd.cmdSetPerformanceOverrideINTEL(command_buffer, p_override_info);
    }

    pub inline fn acquirePerformanceConfigurationINTEL(
        self: Self,
        p_acquire_info: *const vk.PerformanceConfigurationAcquireInfoINTEL,
    ) DeviceDispatch.AcquirePerformanceConfigurationINTELError!vk.PerformanceConfigurationINTEL {
        return self.vkd.acquirePerformanceConfigurationINTEL(self.handle, p_acquire_info);
    }

    pub inline fn releasePerformanceConfigurationINTEL(
        self: Self,
        configuration: vk.PerformanceConfigurationINTEL,
    ) DeviceDispatch.ReleasePerformanceConfigurationINTELError!void {
        return self.vkd.releasePerformanceConfigurationINTEL(self.handle, configuration);
    }

    pub inline fn queueSetPerformanceConfigurationINTEL(
        self: Self,
        queue: vk.Queue,
        configuration: vk.PerformanceConfigurationINTEL,
    ) DeviceDispatch.QueueSetPerformanceConfigurationINTELError!void {
        return self.vkd.queueSetPerformanceConfigurationINTEL(queue, configuration);
    }

    pub inline fn getPerformanceParameterINTEL(
        self: Self,
        parameter: vk.PerformanceParameterTypeINTEL,
    ) DeviceDispatch.GetPerformanceParameterINTELError!vk.PerformanceValueINTEL {
        return self.vkd.getPerformanceParameterINTEL(self.handle, parameter);
    }

    pub inline fn getDeviceMemoryOpaqueCaptureAddress(
        self: Self,
        p_info: *const vk.DeviceMemoryOpaqueCaptureAddressInfo,
    ) u64 {
        return self.vkd.getDeviceMemoryOpaqueCaptureAddress(self.handle, p_info);
    }
    pub inline fn getPipelineExecutablePropertiesKHR(
        self: Self,
        p_pipeline_info: *const vk.PipelineInfoKHR,
        p_executable_count: *u32,
        p_properties: ?[*]vk.PipelineExecutablePropertiesKHR,
    ) DeviceDispatch.GetPipelineExecutablePropertiesKHRError!vk.Result {
        return self.vkd.getPipelineExecutablePropertiesKHR(self.handle, p_pipeline_info, p_executable_count, p_properties);
    }

    pub inline fn getPipelineExecutableStatisticsKHR(
        self: Self,
        p_executable_info: *const vk.PipelineExecutableInfoKHR,
        p_statistic_count: *u32,
        p_statistics: ?[*]vk.PipelineExecutableStatisticKHR,
    ) DeviceDispatch.GetPipelineExecutableStatisticsKHRError!vk.Result {
        return self.vkd.getPipelineExecutableStatisticsKHR(self.handle, p_executable_info, p_statistic_count, p_statistics);
    }

    pub inline fn getPipelineExecutableInternalRepresentationsKHR(
        self: Self,
        p_executable_info: *const vk.PipelineExecutableInfoKHR,
        p_internal_representation_count: *u32,
        p_internal_representations: ?[*]vk.PipelineExecutableInternalRepresentationKHR,
    ) DeviceDispatch.GetPipelineExecutableInternalRepresentationsKHRError!vk.Result {
        return self.vkd.getPipelineExecutableInternalRepresentationsKHR(self.handle, p_executable_info, p_internal_representation_count, p_internal_representations);
    }

    pub inline fn cmdSetLineStippleEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        line_stipple_factor: u32,
        line_stipple_pattern: u16,
    ) void {
        self.vkd.cmdSetLineStippleEXT(command_buffer, line_stipple_factor, line_stipple_pattern);
    }

    pub inline fn createAccelerationStructureKHR(
        self: Self,
        p_create_info: *const vk.AccelerationStructureCreateInfoKHR,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) DeviceDispatch.CreateAccelerationStructureKHRError!vk.AccelerationStructureKHR {
        return self.vkd.createAccelerationStructureKHR(self.handle, p_create_info, p_allocator);
    }

    pub inline fn cmdBuildAccelerationStructuresKHR(
        self: Self,
        command_buffer: vk.CommandBuffer,
        info_count: u32,
        p_infos: [*]const vk.AccelerationStructureBuildGeometryInfoKHR,
        pp_build_range_infos: [*]const [*]const vk.AccelerationStructureBuildRangeInfoKHR,
    ) void {
        return self.vkd.cmdBuildAccelerationStructuresKHR(command_buffer, info_count, p_infos, pp_build_range_infos);
    }

    pub inline fn cmdBuildAccelerationStructuresIndirectKHR(
        self: Self,
        command_buffer: vk.CommandBuffer,
        info_count: u32,
        p_infos: [*]const vk.AccelerationStructureBuildGeometryInfoKHR,
        p_indirect_device_addresses: [*]const vk.DeviceAddress,
        p_indirect_strides: [*]const u32,
        pp_max_primitive_counts: [*]const [*]const u32,
    ) void {
        self.vkd.cmdBuildAccelerationStructuresIndirectKHR(command_buffer, info_count, p_infos, p_indirect_device_addresses, p_indirect_strides, pp_max_primitive_counts);
    }

    pub inline fn buildAccelerationStructuresKHR(
        self: Self,
        deferred_operation: vk.DeferredOperationKHR,
        info_count: u32,
        p_infos: [*]const vk.AccelerationStructureBuildGeometryInfoKHR,
        pp_build_range_infos: [*]const [*]const vk.AccelerationStructureBuildRangeInfoKHR,
    ) DeviceDispatch.BuildAccelerationStructuresKHRError!vk.Result {
        return self.vkd.buildAccelerationStructuresKHR(self.handle, deferred_operation, info_count, p_infos, pp_build_range_infos);
    }

    pub inline fn getAccelerationStructureDeviceAddressKHR(
        self: Self,
        p_info: *const vk.AccelerationStructureDeviceAddressInfoKHR,
    ) vk.DeviceAddress {
        return self.vkd.getAccelerationStructureDeviceAddressKHR(self.handle, p_info);
    }

    pub inline fn createDeferredOperationKHR(
        self: Self,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) DeviceDispatch.CreateDeferredOperationKHRError!vk.DeferredOperationKHR {
        return self.vkd.createDeferredOperationKHR(self.handle, p_allocator);
    }

    pub inline fn destroyDeferredOperationKHR(
        self: Self,
        operation: vk.DeferredOperationKHR,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) void {
        self.vkd.destroyDeferredOperationKHR(self.handle, operation, p_allocator);
    }

    pub inline fn getDeferredOperationMaxConcurrencyKHR(
        self: Self,
        operation: vk.DeferredOperationKHR,
    ) u32 {
        return self.vkd.getDeferredOperationMaxConcurrencyKHR(self.handle, operation);
    }

    pub inline fn getDeferredOperationResultKHR(
        self: Self,
        operation: vk.DeferredOperationKHR,
    ) DeviceDispatch.GetDeferredOperationResultKHRError!vk.Result {
        return self.vkd.getDeferredOperationResultKHR(self.handle, operation);
    }

    pub inline fn deferredOperationJoinKHR(
        self: Self,
        operation: vk.DeferredOperationKHR,
    ) DeviceDispatch.DeferredOperationJoinKHRError!vk.Result {
        return self.vkd.deferredOperationJoinKHR(self.handle, operation);
    }

    pub inline fn cmdSetCullMode(
        self: Self,
        command_buffer: vk.CommandBuffer,
        cull_mode: vk.CullModeFlags,
    ) void {
        self.vkd.cmdSetCullMode(command_buffer, cull_mode);
    }

    pub inline fn cmdSetFrontFace(
        self: Self,
        command_buffer: vk.CommandBuffer,
        front_face: vk.FrontFace,
    ) void {
        self.vkd.cmdSetFrontFace(command_buffer, front_face);
    }

    pub inline fn cmdSetPrimitiveTopology(
        self: Self,
        command_buffer: vk.CommandBuffer,
        primitive_topology: vk.PrimitiveTopology,
    ) void {
        self.vkd.cmdSetPrimitiveTopology(command_buffer, primitive_topology);
    }

    pub inline fn cmdSetViewportWithCount(
        self: Self,
        command_buffer: vk.CommandBuffer,
        viewport_count: u32,
        p_viewports: [*]const vk.Viewport,
    ) void {
        self.vkd.cmdSetViewportWithCount(command_buffer, viewport_count, p_viewports);
    }

    pub inline fn cmdSetScissorWithCount(
        self: Self,
        command_buffer: vk.CommandBuffer,
        scissor_count: u32,
        p_scissors: [*]const vk.Rect2D,
    ) void {
        self.vkd.cmdSetScissorWithCount(command_buffer, scissor_count, p_scissors);
    }

    pub inline fn cmdBindVertexBuffers2(
        self: Self,
        command_buffer: vk.CommandBuffer,
        first_binding: u32,
        binding_count: u32,
        p_buffers: [*]const vk.Buffer,
        p_offsets: [*]const vk.DeviceSize,
        p_sizes: ?[*]const vk.DeviceSize,
        p_strides: ?[*]const vk.DeviceSize,
    ) void {
        self.vkd.cmdBindVertexBuffers2(command_buffer, first_binding, binding_count, p_buffers, p_offsets, p_sizes, p_strides);
    }

    pub inline fn cmdSetDepthTestEnable(
        self: Self,
        command_buffer: vk.CommandBuffer,
        depth_test_enable: vk.Bool32,
    ) void {
        self.vkd.cmdSetDepthTestEnable(command_buffer, depth_test_enable);
    }

    pub inline fn cmdSetDepthWriteEnable(
        self: Self,
        command_buffer: vk.CommandBuffer,
        depth_write_enable: vk.Bool32,
    ) void {
        self.vkd.cmdSetDepthWriteEnable(command_buffer, depth_write_enable);
    }

    pub inline fn cmdSetDepthCompareOp(
        self: Self,
        command_buffer: vk.CommandBuffer,
        depth_compare_op: vk.CompareOp,
    ) void {
        self.vkd.cmdSetDepthCompareOp(command_buffer, depth_compare_op);
    }

    pub inline fn cmdSetDepthBoundsTestEnable(
        self: Self,
        command_buffer: vk.CommandBuffer,
        depth_bounds_test_enable: vk.Bool32,
    ) void {
        self.vkd.cmdSetDepthBoundsTestEnable(command_buffer, depth_bounds_test_enable);
    }

    pub inline fn cmdSetStencilTestEnable(
        self: Self,
        command_buffer: vk.CommandBuffer,
        stencil_test_enable: vk.Bool32,
    ) void {
        self.vkd.cmdSetStencilTestEnable(command_buffer, stencil_test_enable);
    }

    pub inline fn cmdSetStencilOp(
        self: Self,
        command_buffer: vk.CommandBuffer,
        face_mask: vk.StencilFaceFlags,
        fail_op: vk.StencilOp,
        pass_op: vk.StencilOp,
        depth_fail_op: vk.StencilOp,
        compare_op: vk.CompareOp,
    ) void {
        self.vkd.cmdSetStencilOp(command_buffer, face_mask, fail_op, pass_op, depth_fail_op, compare_op);
    }

    pub inline fn cmdSetPatchControlPointsEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        patch_control_points: u32,
    ) void {
        self.vkd.cmdSetPatchControlPointsEXT(command_buffer, patch_control_points);
    }

    pub inline fn cmdSetRasterizerDiscardEnable(
        self: Self,
        command_buffer: vk.CommandBuffer,
        rasterizer_discard_enable: vk.Bool32,
    ) void {
        self.vkd.cmdSetRasterizerDiscardEnable(command_buffer, rasterizer_discard_enable);
    }

    pub inline fn cmdSetDepthBiasEnable(
        self: Self,
        command_buffer: vk.CommandBuffer,
        depth_bias_enable: vk.Bool32,
    ) void {
        self.vkd.cmdSetDepthBiasEnable(command_buffer, depth_bias_enable);
    }

    pub inline fn cmdSetLogicOpEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        logic_op: vk.LogicOp,
    ) void {
        self.vkd.cmdSetLogicOpEXT(command_buffer, logic_op);
    }

    pub inline fn cmdSetPrimitiveRestartEnable(
        self: Self,
        command_buffer: vk.CommandBuffer,
        primitive_restart_enable: vk.Bool32,
    ) void {
        self.vkd.cmdSetPrimitiveRestartEnable(command_buffer, primitive_restart_enable);
    }

    pub inline fn createPrivateDataSlot(
        self: Self,
        p_create_info: *const vk.PrivateDataSlotCreateInfo,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) DeviceDispatch.CreatePrivateDataSlotError!vk.PrivateDataSlot {
        return self.vkd.createPrivateDataSlot(self.handle, p_create_info, p_allocator);
    }

    pub inline fn cmdSetTessellationDomainOriginEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        domain_origin: vk.TessellationDomainOrigin,
    ) void {
        self.vkd.cmdSetTessellationDomainOriginEXT(command_buffer, domain_origin);
    }

    pub inline fn cmdSetDepthClampEnableEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        depth_clamp_enable: vk.Bool32,
    ) void {
        self.vkd.cmdSetDepthClampEnableEXT(command_buffer, depth_clamp_enable);
    }

    pub inline fn cmdSetPolygonModeEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        polygon_mode: vk.PolygonMode,
    ) void {
        self.vkd.cmdSetPolygonModeEXT(command_buffer, polygon_mode);
    }

    pub inline fn cmdSetRasterizationSamplesEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        rasterization_samples: vk.SampleCountFlags,
    ) void {
        self.vkd.cmdSetRasterizationSamplesEXT(command_buffer, rasterization_samples);
    }

    pub inline fn cmdSetSampleMaskEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        samples: vk.SampleCountFlags,
        p_sample_mask: [*]const vk.SampleMask,
    ) void {
        self.vkd.cmdSetSampleMaskEXT(command_buffer, samples, p_sample_mask);
    }

    pub inline fn cmdSetAlphaToCoverageEnableEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        alpha_to_coverage_enable: vk.Bool32,
    ) void {
        self.vkd.cmdSetAlphaToCoverageEnableEXT(command_buffer, alpha_to_coverage_enable);
    }

    pub inline fn cmdSetAlphaToOneEnableEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        alpha_to_one_enable: vk.Bool32,
    ) void {
        self.vkd.cmdSetAlphaToOneEnableEXT(command_buffer, alpha_to_one_enable);
    }

    pub inline fn cmdSetLogicOpEnableEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        logic_op_enable: vk.Bool32,
    ) void {
        self.vkd.cmdSetLogicOpEnableEXT(command_buffer, logic_op_enable);
    }

    pub inline fn cmdSetColorBlendEnableEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        first_attachment: u32,
        attachment_count: u32,
        p_color_blend_enables: [*]const vk.Bool32,
    ) void {
        self.vkd.cmdSetColorBlendEnableEXT(command_buffer, first_attachment, attachment_count, p_color_blend_enables);
    }

    pub inline fn cmdSetColorBlendEquationEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        first_attachment: u32,
        attachment_count: u32,
        p_color_blend_equations: [*]const vk.ColorBlendEquationEXT,
    ) void {
        self.vkd.cmdSetColorBlendEquationEXT(command_buffer, first_attachment, attachment_count, p_color_blend_equations);
    }

    pub inline fn cmdSetColorWriteMaskEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        first_attachment: u32,
        attachment_count: u32,
        p_color_write_masks: [*]const vk.ColorComponentFlags,
    ) void {
        self.vkd.cmdSetColorWriteMaskEXT(command_buffer, first_attachment, attachment_count, p_color_write_masks);
    }

    pub inline fn cmdSetRasterizationStreamEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        rasterization_stream: u32,
    ) void {
        self.vkd.cmdSetRasterizationStreamEXT(command_buffer, rasterization_stream);
    }

    pub inline fn cmdSetConservativeRasterizationModeEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        conservative_rasterization_mode: vk.ConservativeRasterizationModeEXT,
    ) void {
        self.vkd.cmdSetConservativeRasterizationModeEXT(command_buffer, conservative_rasterization_mode);
    }

    pub inline fn cmdSetExtraPrimitiveOverestimationSizeEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        extra_primitive_overestimation_size: f32,
    ) void {
        self.vkd.cmdSetExtraPrimitiveOverestimationSizeEXT(command_buffer, extra_primitive_overestimation_size);
    }

    pub inline fn cmdSetDepthClipEnableEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        depth_clip_enable: vk.Bool32,
    ) void {
        self.vkd.cmdSetDepthClipEnableEXT(command_buffer, depth_clip_enable);
    }

    pub inline fn cmdSetSampleLocationsEnableEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        sample_locations_enable: vk.Bool32,
    ) void {
        self.vkd.cmdSetSampleLocationsEXT(command_buffer, sample_locations_enable);
    }

    pub inline fn cmdSetColorBlendAdvancedEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        first_attachment: u32,
        attachment_count: u32,
        p_color_blend_advanced: [*]const vk.ColorBlendAdvancedEXT,
    ) void {
        self.vkd.cmdSetColorBlendAdvancedEXT(command_buffer, first_attachment, attachment_count, p_color_blend_advanced);
    }

    pub inline fn cmdSetProvokingVertexModeEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        provoking_vertex_mode: vk.ProvokingVertexModeEXT,
    ) void {
        self.vkd.cmdSetProvokingVertexModeEXT(command_buffer, provoking_vertex_mode);
    }

    pub inline fn cmdSetLineRasterizationModeEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        line_rasterization_mode: vk.LineRasterizationModeEXT,
    ) void {
        self.vkd.cmdSetLineRasterizationModeEXT(command_buffer, line_rasterization_mode);
    }

    pub inline fn cmdSetLineStippleEnableEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        stippled_line_enable: vk.Bool32,
    ) void {
        self.vkd.cmdSetLineStippleEnableEXT(command_buffer, stippled_line_enable);
    }

    // =

    pub inline fn cmdSetDepthClipNegativeOneToOneEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        negative_one_to_one: vk.Bool32,
    ) void {
        self.vkd.cmdSetDepthClipNegativeOneToOneEXT(command_buffer, negative_one_to_one);
    }

    pub inline fn cmdSetViewportWScalingEnableNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        viewport_w_scaling_enable: vk.Bool32,
    ) void {
        self.vkd.cmdSetViewportWScalingEnableNV(command_buffer, viewport_w_scaling_enable);
    }

    pub inline fn cmdSetViewportSwizzleNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        first_viewport: u32,
        viewport_count: u32,
        p_viewport_swizzles: [*]const vk.ViewportSwizzleNV,
    ) void {
        self.vkd.cmdSetViewportSwizzleNV(command_buffer, first_viewport, viewport_count, p_viewport_swizzles);
    }

    pub inline fn cmdSetCoverageToColorEnableNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        coverage_to_color_enable: vk.Bool32,
    ) void {
        self.vkd.cmdSetCoverageToColorEnableNV(command_buffer, coverage_to_color_enable);
    }

    pub inline fn cmdSetCoverageToColorLocationNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        coverage_to_color_location: u32,
    ) void {
        self.vkd.cmdSetCoverageToColorLocationNV(command_buffer, coverage_to_color_location);
    }

    pub inline fn cmdSetCoverageModulationModeNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        coverage_modulation_mode: vk.CoverageModulationModeNV,
    ) void {
        self.vkd.cmdSetCoverageModulationModeNV(command_buffer, coverage_modulation_mode);
    }

    pub inline fn cmdSetCoverageModulationTableEnableNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        coverage_modulation_table_enable: vk.Bool32,
    ) void {
        self.vkd.cmdSetCoverageModulationTableEnableNV(command_buffer, coverage_modulation_table_enable);
    }

    pub inline fn cmdSetCoverageModulationTableNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        coverage_modulation_table_count: u32,
        p_coverage_modulation_table: [*]const f32,
    ) void {
        self.vkd.cmdSetCoverageModulationTableNV(command_buffer, coverage_modulation_table_count, p_coverage_modulation_table);
    }

    pub inline fn cmdSetShadingRateImageEnableNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        shading_rate_image_enable: vk.Bool32,
    ) void {
        self.vkd.cmdSetShadingRateImageEnableNV(command_buffer, shading_rate_image_enable);
    }

    pub inline fn cmdSetCoverageReductionModeNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        coverage_reduction_mode: vk.CoverageReductionModeNV,
    ) void {
        self.vkd.cmdSetCoverageReductionModeNV(command_buffer, coverage_reduction_mode);
    }

    pub inline fn cmdSetRepresentativeFragmentTestEnableNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        representative_fragment_test_enable: vk.Bool32,
    ) void {
        self.vkd.cmdSetRepresentativeFragmentTestEnableNV(command_buffer, representative_fragment_test_enable);
    }

    pub inline fn destroyPrivateDataSlot(
        self: Self,
        private_data_slot: vk.PrivateDataSlot,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) void {
        self.vkd.destroyPrivateDataSlot(self.handle, private_data_slot, p_allocator);
    }

    pub inline fn setPrivateData(
        self: Self,
        object_type: vk.ObjectType,
        object_handle: u64,
        private_data_slot: vk.PrivateDataSlot,
        data: u64,
    ) DeviceDispatch.SetPrivateDataError!void {
        return self.vkd.setPrivateData(self.handle, object_type, object_handle, private_data_slot, data);
    }

    pub inline fn getPrivateData(
        self: Self,
        object_type: vk.ObjectType,
        object_handle: u64,
        private_data_slot: vk.PrivateDataSlot,
    ) u64 {
        return self.vkd.getPrivateData(self.handle, object_type, object_handle, private_data_slot);
    }

    pub inline fn cmdCopyBuffer2(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_copy_buffer_info: *const vk.CopyBufferInfo2,
    ) void {
        self.vkd.cmdCopyBuffer2(command_buffer, p_copy_buffer_info);
    }

    pub inline fn cmdCopyImage2(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_copy_image_info: *const vk.CopyImageInfo2,
    ) void {
        self.vkd.cmdCopyImage2(command_buffer, p_copy_image_info);
    }

    pub inline fn cmdBlitImage2(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_blit_image_info: *const vk.BlitImageInfo2,
    ) void {
        self.vkd.cmdBlitImage2(command_buffer, p_blit_image_info);
    }

    pub inline fn cmdCopyBufferToImage2(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_copy_buffer_to_image_info: *const vk.CopyBufferToImageInfo2,
    ) void {
        self.vkd.cmdCopyBufferToImage2(command_buffer, p_copy_buffer_to_image_info);
    }

    pub inline fn cmdCopyImageToBuffer2(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_copy_image_to_buffer_info: *const vk.CopyImageToBufferInfo2,
    ) void {
        self.vkd.cmdCopyImageToBuffer2(command_buffer, p_copy_image_to_buffer_info);
    }

    pub inline fn cmdResolveImage2(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_resolve_image_info: *const vk.ResolveImageInfo2,
    ) void {
        self.vkd.cmdResolveImage2(command_buffer, p_resolve_image_info);
    }

    pub inline fn cmdSetFragmentShadingRateKHR(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_fragment_size: *const vk.Extent2D,
        combiner_ops: *const [2]vk.FragmentShadingRateCombinerOpKHR,
    ) void {
        self.vkd.cmdSetFragmentShadingRateKHR(command_buffer, p_fragment_size, combiner_ops);
    }

    pub inline fn cmdSetFragmentShadingRateEnumNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        shading_rate: vk.FragmentShadingRateNV,
        combiner_ops: *const [2]vk.FragmentShadingRateCombinerOpKHR,
    ) void {
        self.vkd.cmdSetFragmentShadingRateEnumNV(command_buffer, shading_rate, combiner_ops);
    }

    pub inline fn getAccelerationStructureBuildSizesKHR(
        self: Self,
        build_type: vk.AccelerationStructureBuildTypeKHR,
        p_build_info: *const vk.AccelerationStructureBuildGeometryInfoKHR,
        p_max_primitive_counts: ?[*]const u32,
        p_size_info: *vk.AccelerationStructureBuildSizesInfoKHR,
    ) void {
        self.vkd.getAccelerationStructureBuildSizesKHR(self.handle, build_type, p_build_info, p_max_primitive_counts, p_size_info);
    }

    pub inline fn cmdSetVertexInputEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        vertex_binding_description_count: u32,
        p_vertex_binding_descriptions: [*]const vk.VertexInputBindingDescription2EXT,
        vertex_attribute_description_count: u32,
        p_vertex_attribute_descriptions: [*]const vk.VertexInputAttributeDescription2EXT,
    ) void {
        self.vkd.cmdSetVertexInputEXT(
            command_buffer,
            vertex_binding_description_count,
            p_vertex_binding_descriptions,
            vertex_attribute_description_count,
            p_vertex_attribute_descriptions,
        );
    }

    pub inline fn cmdSetColorWriteEnableEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        attachment_count: u32,
        p_color_write_enables: [*]const vk.Bool32,
    ) void {
        self.vkd.cmdSetColorWriteEnableEXT(command_buffer, attachment_count, p_color_write_enables);
    }

    pub inline fn cmdSetEvent2(
        self: Self,
        command_buffer: vk.CommandBuffer,
        event: vk.Event,
        p_dependency_info: *const vk.DependencyInfo,
    ) void {
        self.vkd.cmdSetEvent2(command_buffer, event, p_dependency_info);
    }

    pub inline fn cmdResetEvent2(
        self: Self,
        command_buffer: vk.CommandBuffer,
        event: vk.Event,
        stage_mask: vk.PipelineStageFlags2,
    ) void {
        self.vkd.cmdResetEvent2(command_buffer, event, stage_mask);
    }

    pub inline fn cmdWaitEvents2(
        self: Self,
        command_buffer: vk.CommandBuffer,
        event_count: u32,
        p_events: [*]const vk.Event,
        p_dependency_infos: [*]const vk.DependencyInfo,
    ) void {
        self.vkd.cmdWaitEvents2(command_buffer, event_count, p_events, p_dependency_infos);
    }

    pub inline fn cmdPipelineBarrier2(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_dependency_info: *const vk.DependencyInfo,
    ) void {
        self.vkd.cmdPipelineBarrier2(command_buffer, p_dependency_info);
    }

    pub inline fn queueSubmit2(
        self: Self,
        queue: vk.Queue,
        submit_count: u32,
        p_submits: [*]const vk.SubmitInfo2,
        fence: vk.Fence,
    ) DeviceDispatch.QueueSubmit2Error!void {
        self.vkd.queueSubmit2(queue, submit_count, p_submits, fence);
    }

    pub inline fn cmdWriteTimestamp2(
        self: Self,
        command_buffer: vk.CommandBuffer,
        stage: vk.PipelineStageFlags2,
        query_pool: vk.QueryPool,
        query: u32,
    ) void {
        self.vkd.cmdWriteTimestamp2(command_buffer, stage, query_pool, query);
    }

    pub inline fn cmdWriteBufferMarker2AMD(
        self: Self,
        command_buffer: vk.CommandBuffer,
        stage: vk.PipelineStageFlags2,
        dst_buffer: vk.Buffer,
        dst_offset: vk.DeviceSize,
        marker: u32,
    ) void {
        self.vkd.cmdWriteBufferMarker2AMD(command_buffer, stage, dst_buffer, dst_offset, marker);
    }

    pub inline fn getQueueCheckpointData2NV(
        self: Self,
        queue: vk.Queue,
        p_checkpoint_data_count: *u32,
        p_checkpoint_data: ?[*]vk.CheckpointData2NV,
    ) void {
        self.vkd.getQueueCheckpointData2NV(queue, p_checkpoint_data_count, p_checkpoint_data);
    }

    pub inline fn createVideoSessionKHR(
        self: Self,
        p_create_info: *const vk.VideoSessionCreateInfoKHR,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) DeviceDispatch.CreateVideoSessionKHRError!vk.VideoSessionKHR {
        return self.vkd.createVideoSessionKHR(self.handle, p_create_info, p_allocator);
    }

    pub inline fn destroyVideoSessionKHR(
        self: Self,
        video_session: vk.VideoSessionKHR,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) void {
        self.vkd.destroyVideoSessionKHR(self.handle, video_session, p_allocator);
    }

    pub inline fn createVideoSessionParametersKHR(
        self: Self,
        p_create_info: *const vk.VideoSessionParametersCreateInfoKHR,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) DeviceDispatch.CreateVideoSessionParametersKHRError!vk.VideoSessionParametersKHR {
        return self.vkd.createVideoSessionParametersKHR(self.handle, p_create_info, p_allocator);
    }

    pub inline fn updateVideoSessionParametersKHR(
        self: Self,
        video_session_parameters: vk.VideoSessionParametersKHR,
        p_update_info: *const vk.VideoSessionParametersUpdateInfoKHR,
    ) DeviceDispatch.UpdateVideoSessionParametersKHRError!void {
        return self.vkd.updateVideoSessionParametersKHR(self.handle, video_session_parameters, p_update_info);
    }

    pub inline fn destroyVideoSessionParametersKHR(
        self: Self,
        video_session_parameters: vk.VideoSessionParametersKHR,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) void {
        self.vkd.destroyVideoSessionParametersKHR(self.handle, video_session_parameters, p_allocator);
    }

    pub inline fn getVideoSessionMemoryRequirementsKHR(
        self: Self,
        video_session: vk.VideoSessionKHR,
        p_memory_requirements_count: *u32,
        p_memory_requirements: ?[*]vk.VideoSessionMemoryRequirementsKHR,
    ) DeviceDispatch.GetVideoSessionMemoryRequirementsKHRError!vk.Result {
        return self.vkd.getVideoSessionMemoryRequirementsKHR(self.handle, video_session, p_memory_requirements_count, p_memory_requirements);
    }

    pub inline fn bindVideoSessionMemoryKHR(
        self: Self,
        video_session: vk.VideoSessionKHR,
        bind_session_memory_info_count: u32,
        p_bind_session_memory_infos: [*]const vk.BindVideoSessionMemoryInfoKHR,
    ) DeviceDispatch.BindVideoSessionMemoryKHRError!void {
        return self.vkd.bindVideoSessionMemoryKHR(self.handle, video_session, bind_session_memory_info_count, p_bind_session_memory_infos);
    }

    pub inline fn cmdDecodeVideoKHR(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_decode_info: *const vk.VideoDecodeInfoKHR,
    ) void {
        self.vkd.cmdDecodeVideoKHR(command_buffer, p_decode_info);
    }

    pub inline fn cmdBeginVideoCodingKHR(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_begin_info: *const vk.VideoBeginCodingInfoKHR,
    ) void {
        self.vkd.cmdBeginVideoCodingKHR(command_buffer, p_begin_info);
    }

    pub inline fn cmdControlVideoCodingKHR(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_coding_control_info: *const vk.VideoCodingControlInfoKHR,
    ) void {
        self.vkd.cmdControlVideoCodingKHR(command_buffer, p_coding_control_info);
    }

    pub inline fn cmdEndVideoCodingKHR(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_end_coding_info: *const vk.VideoEndCodingInfoKHR,
    ) void {
        self.vkd.cmdEndVideoCodingKHR(command_buffer, p_end_coding_info);
    }

    pub inline fn cmdEncodeVideoKHR(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_encode_info: *const vk.VideoEncodeInfoKHR,
    ) void {
        self.vkd.cmdEncodeVideoKHR(command_buffer, p_encode_info);
    }

    pub inline fn createCuModuleNVX(
        self: Self,
        p_create_info: *const vk.CuModuleCreateInfoNVX,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) DeviceDispatch.CreateCuModuleNVXError!vk.CuModuleNVX {
        return self.vkd.createCuModuleNVX(self.handle, p_create_info, p_allocator);
    }

    pub inline fn createCuFunctionNVX(
        self: Self,
        p_create_info: *const vk.CuFunctionCreateInfoNVX,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) DeviceDispatch.CreateCuFunctionNVXError!vk.CuFunctionNVX {
        return self.vkd.createCuFunctionNVX(self.handle, p_create_info, p_allocator);
    }

    pub inline fn destroyCuModuleNVX(
        self: Self,
        module: vk.CuModuleNVX,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) void {
        self.vkd.destroyCuModuleNVX(self.handle, module, p_allocator);
    }

    pub inline fn destroyCuFunctionNVX(
        self: Self,
        function: vk.CuFunctionNVX,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) void {
        self.vkd.destroyCuModuleNVX(self.handle, function, p_allocator);
    }

    pub inline fn cmdCuLaunchKernelNVX(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_launch_info: *const vk.CuLaunchInfoNVX,
    ) void {
        self.vkd.cmdCuLaunchKernelNVX(command_buffer, p_launch_info);
    }

    pub inline fn setDeviceMemoryPriorityEXT(
        self: Self,
        memory: vk.DeviceMemory,
        priority: f32,
    ) void {
        self.vkd.setDeviceMemoryPriorityEXT(self.handle, memory, priority);
    }

    pub inline fn waitForPresentKHR(
        self: Self,
        swapchain: vk.SwapchainKHR,
        present_id: u64,
        timeout: u64,
    ) DeviceDispatch.WaitForPresentKHRError!vk.Result {
        return self.vkd.waitForPresentKHR(self.handle, swapchain, present_id, timeout);
    }

    pub inline fn createBufferCollectionFUCHSIA(
        self: Self,
        p_create_info: *const vk.BufferCollectionCreateInfoFUCHSIA,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) DeviceDispatch.CreateBufferCollectionFUCHSIAError!vk.BufferCollectionFUCHSIA {
        return self.vkd.createBufferCollectionFUCHSIA(self.handle, p_create_info, p_allocator);
    }

    pub inline fn setBufferCollectionBufferConstraintsFUCHSIA(
        self: Self,
        collection: vk.BufferCollectionFUCHSIA,
        p_buffer_constraints_info: *const vk.BufferConstraintsInfoFUCHSIA,
    ) DeviceDispatch.SetBufferCollectionBufferConstraintsFUCHSIAError!void {
        return self.vkd.setBufferCollectionBufferConstraintsFUCHSIA(self.handle, collection, p_buffer_constraints_info);
    }

    pub inline fn setBufferCollectionImageConstraintsFUCHSIA(
        self: Self,
        collection: vk.BufferCollectionFUCHSIA,
        p_image_constraints_info: *const vk.ImageConstraintsInfoFUCHSIA,
    ) DeviceDispatch.SetBufferCollectionImageConstraintsFUCHSIAError!void {
        return self.vkd.setBufferCollectionImageConstraintsFUCHSIA(self.handle, collection, p_image_constraints_info);
    }

    pub inline fn destroyBufferCollectionFUCHSIA(
        self: Self,
        collection: vk.BufferCollectionFUCHSIA,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) void {
        self.vkd.destroyBufferCollectionFUCHSIA(self.handle, collection, p_allocator);
    }

    pub inline fn getBufferCollectionPropertiesFUCHSIA(
        self: Self,
        collection: vk.BufferCollectionFUCHSIA,
        p_properties: *vk.BufferCollectionPropertiesFUCHSIA,
    ) DeviceDispatch.GetBufferCollectionPropertiesFUCHSIAError!void {
        return self.vkd.getBufferCollectionPropertiesFUCHSIA(self.handle, collection, p_properties);
    }

    pub inline fn cmdBeginRendering(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_rendering_info: *const vk.RenderingInfo,
    ) void {
        self.vkd.cmdBeginRendering(command_buffer, p_rendering_info);
    }

    pub inline fn cmdEndRendering(
        self: Self,
        command_buffer: vk.CommandBuffer,
    ) void {
        self.vkd.cmdEndRendering(command_buffer);
    }

    pub inline fn getDescriptorSetLayoutHostMappingInfoVALVE(
        self: Self,
        p_binding_reference: *const vk.DescriptorSetBindingReferenceVALVE,
        p_host_mapping: *vk.DescriptorSetLayoutHostMappingInfoVALVE,
    ) void {
        self.vkd.getDescriptorSetLayoutHostMappingInfoVALVE(self.handle, p_binding_reference, p_host_mapping);
    }

    pub inline fn getDescriptorSetHostMappingVALVE(
        self: Self,
        descriptor_set: vk.DescriptorSet,
    ) *anyopaque {
        return self.vkd.getDescriptorSetHostMappingVALVE(self.handle, descriptor_set);
    }
    pub inline fn createMicromapEXT(
        self: Self,
        p_create_info: *const vk.MicromapCreateInfoEXT,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) DeviceDispatch.CreateMicromapEXTError!vk.MicromapEXT {
        return self.vkd.createMicromapEXT(self.handle, p_create_info, p_allocator);
    }

    pub inline fn cmdBuildMicromapsEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        info_count: u32,
        p_infos: [*]const vk.MicromapBuildInfoEXT,
    ) void {
        return self.vkd.cmdBuildMicromapsEXT(command_buffer, info_count, p_infos);
    }

    pub inline fn buildMicromapsEXT(
        self: Self,
        deferred_operation: vk.DeferredOperationKHR,
        info_count: u32,
        p_infos: [*]const vk.MicromapBuildInfoEXT,
    ) DeviceDispatch.BuildMicromapsEXTError!vk.Result {
        return self.vkd.buildMicromapsEXT(self.handle, deferred_operation, info_count, p_infos);
    }

    pub inline fn destroyMicromapEXT(
        self: Self,
        micromap: vk.MicromapEXT,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) void {
        self.vkd.destroyMicromapEXT(self.handle, micromap, p_allocator);
    }

    pub inline fn cmdCopyMicromapEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_info: *const vk.CopyMicromapInfoEXT,
    ) void {
        self.vkd.cmdCopyMicromapEXT(command_buffer, p_info);
    }

    pub inline fn copyMicromapEXT(
        self: Self,
        deferred_operation: vk.DeferredOperationKHR,
        p_info: *const vk.CopyMicromapInfoEXT,
    ) DeviceDispatch.CopyMicromapEXTError!vk.Result {
        return self.vkd.copyMicromapEXT(self.handle, deferred_operation, p_info);
    }

    pub inline fn cmdCopyMicromapToMemoryEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_info: *const vk.CopyMicromapToMemoryInfoEXT,
    ) void {
        self.vkd.cmdCopyMicromapToMemoryEXT(command_buffer, p_info);
    }

    pub inline fn copyMicromapToMemoryEXT(
        self: Self,
        deferred_operation: vk.DeferredOperationKHR,
        p_info: *const vk.CopyMicromapToMemoryInfoEXT,
    ) DeviceDispatch.CopyMicromapToMemoryEXTError!vk.Result {
        return self.vkd.copyMicromapToMemoryEXT(self.handle, deferred_operation, p_info);
    }

    pub inline fn cmdCopyMemoryToMicromapEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        p_info: *const vk.CopyMemoryToMicromapInfoEXT,
    ) void {
        return self.vkd.cmdCopyMemoryToMicromapEXT(command_buffer, p_info);
    }

    pub inline fn copyMemoryToMicromapEXT(
        self: Self,
        deferred_operation: vk.DeferredOperationKHR,
        p_info: *const vk.CopyMemoryToMicromapInfoEXT,
    ) DeviceDispatch.CopyMemoryToMicromapEXTError!vk.Result {
        return self.vkd.copyMemoryToMicromapEXT(self.handle, deferred_operation, p_info);
    }

    pub inline fn cmdWriteMicromapsPropertiesEXT(
        self: Self,
        command_buffer: vk.CommandBuffer,
        micromap_count: u32,
        p_micromaps: [*]const vk.MicromapEXT,
        query_type: vk.QueryType,
        query_pool: vk.QueryPool,
        first_query: u32,
    ) void {
        self.vkd.cmdWriteMicromapsPropertiesEXT(command_buffer, micromap_count, p_micromaps, query_type, query_pool, first_query);
    }

    pub inline fn writeMicromapsPropertiesEXT(
        self: Self,
        micromap_count: u32,
        p_micromaps: [*]const vk.MicromapEXT,
        query_type: vk.QueryType,
        data_size: usize,
        p_data: *anyopaque,
        stride: usize,
    ) DeviceDispatch.WriteMicromapsPropertiesEXTError!void {
        return self.vkd.writeMicromapsPropertiesEXT(self.handle, micromap_count, p_micromaps, query_type, data_size, p_data, stride);
    }

    pub inline fn getDeviceMicromapCompatibilityEXT(
        self: Self,
        p_version_info: *const vk.MicromapVersionInfoEXT,
    ) vk.AccelerationStructureCompatibilityKHR {
        return self.vkd.getDeviceMicromapCompatibilityEXT(self.handle, p_version_info);
    }

    pub inline fn getMicromapBuildSizesEXT(
        self: Self,
        build_type: vk.AccelerationStructureBuildTypeKHR,
        p_build_info: *const vk.MicromapBuildInfoEXT,
        p_size_info: *vk.MicromapBuildSizesInfoEXT,
    ) void {
        self.vkd.getMicromapBuildSizesEXT(self.handle, build_type, p_build_info, p_size_info);
    }

    pub inline fn getShaderModuleIdentifierEXT(
        self: Self,
        shader_module: vk.ShaderModule,
        p_identifier: *vk.ShaderModuleIdentifierEXT,
    ) void {
        self.vkd.getShaderModuleIdentifierEXT(self.handle, shader_module, p_identifier);
    }

    pub inline fn getShaderModuleCreateInfoIdentifierEXT(
        self: Self,
        p_create_info: *const vk.ShaderModuleCreateInfo,
        p_identifier: *vk.ShaderModuleIdentifierEXT,
    ) void {
        self.vkd.getShaderModuleCreateInfoIdentifierEXT(self.handle, p_create_info, p_identifier);
    }

    pub inline fn getImageSubresourceLayout2EXT(
        self: Self,
        image: vk.Image,
        p_subresource: *const vk.ImageSubresource2EXT,
        p_layout: *vk.SubresourceLayout2EXT,
    ) void {
        self.vkd.getImageSubresourceLayout2EXT(self.handle, image, p_subresource, p_layout);
    }

    pub inline fn getPipelinePropertiesEXT(
        self: Self,
        p_pipeline_info: *const vk.PipelineInfoEXT,
        p_pipeline_properties: *vk.BaseOutStructure,
    ) DeviceDispatch.GetPipelinePropertiesEXTError!void {
        return self.vkd.getPipelinePropertiesEXT(self.handle, p_pipeline_info, p_pipeline_properties);
    }

    pub inline fn exportMetalObjectsEXT(
        self: Self,
        p_metal_objects_info: *vk.ExportMetalObjectsInfoEXT,
    ) void {
        self.vkd.exportMetalObjectsEXT(self.handle, p_metal_objects_info);
    }

    pub inline fn getFramebufferTilePropertiesQCOM(
        self: Self,
        framebuffer: vk.Framebuffer,
        p_properties_count: *u32,
        p_properties: ?[*]vk.TilePropertiesQCOM,
    ) DeviceDispatch.GetFramebufferTilePropertiesQCOMError!vk.Result {
        return self.vkd.getFramebufferTilePropertiesQCOM(self.handle, framebuffer, p_properties_count, p_properties);
    }

    pub inline fn getDynamicRenderingTilePropertiesQCOM(
        self: Self,
        p_rendering_info: *const vk.RenderingInfo,
        p_properties: *vk.TilePropertiesQCOM,
    ) DeviceDispatch.GetDynamicRenderingTilePropertiesQCOMError!void {
        return self.vkd.getDynamicRenderingTilePropertiesQCOM(self.handle, p_rendering_info, p_properties);
    }

    pub inline fn createOpticalFlowSessionNV(
        self: Self,
        p_create_info: *const vk.OpticalFlowSessionCreateInfoNV,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) DeviceDispatch.CreateOpticalFlowSessionNVError!vk.OpticalFlowSessionNV {
        return self.vkd.createOpticalFlowSessionNV(self.handle, p_create_info, p_allocator);
    }

    pub inline fn destroyOpticalFlowSessionNV(
        self: Self,
        session: vk.OpticalFlowSessionNV,
        p_allocator: ?*const vk.AllocationCallbacks,
    ) void {
        self.vkd.destroyOpticalFlowSessionNV(self.handle, session, p_allocator);
    }

    pub inline fn bindOpticalFlowSessionImageNV(
        self: Self,
        session: vk.OpticalFlowSessionNV,
        binding_point: vk.OpticalFlowSessionBindingPointNV,
        view: vk.ImageView,
        layout: vk.ImageLayout,
    ) DeviceDispatch.BindOpticalFlowSessionImageNVError!void {
        return self.vkd.bindOpticalFlowSessionImageNV(self.handle, session, binding_point, view, layout);
    }

    pub inline fn cmdOpticalFlowExecuteNV(
        self: Self,
        command_buffer: vk.CommandBuffer,
        session: vk.OpticalFlowSessionNV,
        p_execute_info: *const vk.OpticalFlowExecuteInfoNV,
    ) void {
        self.vkd.cmdOpticalFlowExecuteNV(command_buffer, session, p_execute_info);
    }

    pub inline fn getDeviceFaultInfoEXT(
        self: Self,
        p_fault_counts: *vk.DeviceFaultCountsEXT,
        p_fault_info: ?*vk.DeviceFaultInfoEXT,
    ) DeviceDispatch.GetDeviceFaultInfoEXTError!vk.Result {
        return self.vkd.getDeviceFaultInfoEXT(self.handle, p_fault_counts, p_fault_info);
    }
};
