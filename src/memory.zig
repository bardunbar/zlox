const std = @import("std");
const object_mod = @import("object.zig");
const Object = object_mod.Object;
const ObjectString = object_mod.ObjectString;

pub const Manager = struct {
    objects: ?*Object,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) @This() {
        return .{
            .objects = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *@This()) void {
        var objects = self.objects;
        while (objects) |object| {
            const next = object.next;
            object.deinit(self.allocator);
            objects = next;
        }
    }

    pub fn copy(self: *@This(), str: []const u8) !*Object {
        var new = try ObjectString.copy(str, self.allocator);
        new.object.next = self.objects;
        self.objects = &new.object;
        return &new.object;
    }

    pub fn concat(self: *@This(), a: []const u8, b: []const u8) !*Object {
        const result = try std.mem.concat(self.allocator, u8, &[_][]const u8{ a, b });
        var new = try ObjectString.take(result, self.allocator);
        new.object.next = self.objects;
        self.objects = &new.object;
        return &new.object;
    }
};
