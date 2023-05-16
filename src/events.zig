const std = @import("std");
const Allocator = std.mem.Allocator;

var allocator: Allocator = undefined;

pub fn initEventSystem(in_allocator: Allocator)
    allocator = in_allocator;
}


pub fn registerListener(comptime EventType: type, listen_func: *const fn(EventType) void) void {
    @typeName()   //
}




// pub const PfnGetDeviceQueue = *const fn (
//     device: Device,
//     queue_family_index: u32,
//     queue_index: u32,
//     p_queue: *Queue,
// ) callconv(vulkan_call_conv) void;



const WindowResizeEvent = struct {
    width: u32,
    height: u32,
};




// pub fn broadcast(comptime T: type, event_data: T) void {
//     comptime switch(T) {
//     }
// }



