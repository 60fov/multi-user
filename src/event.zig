const std = @import("std");

pub const EventTag = enum {
    window_create,
    app_quit,
};

pub const Event = union(EventTag) {
    window_create: void,
    app_quit: void,
};

pub const EventQueue = struct {
    const ListType = std.DoublyLinkedList(Event);

    allocator: std.heap.ArenaAllocator,
    list: std.DoublyLinkedList(Event) = ListType{},

    pub fn init(allocator: std.mem.Allocator) EventQueue {
        return EventQueue{
            .allocator = std.heap.ArenaAllocator.init(allocator),
        };
    }

    pub fn deinit(self: *EventQueue) void {
        self.allocator.deinit();
        self.* = undefined;
    }

    pub fn push(self: *EventQueue, event: Event) !void {
        const node = ListType.Node{ .data = event };
        self.list.append(node);
    }

    pub fn pop(self: *EventQueue) ?Event {
        return self.list.popFirst();
    }

    pub fn flush(self: *EventQueue) void {
        self.allocator.reset(.retain_capacity);
    }
};

var event_queue: std.DoublyLinkedList(Event) = undefined;
var allcator: std.mem.Allcator = undefined;
