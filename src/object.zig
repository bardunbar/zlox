const std = @import("std");

pub const ObjectType = enum {
    obj_string,
};

pub const Object = struct {
    kind: ObjectType,
    next: ?*Object,

    pub fn isA(self: @This(), comptime T: type) bool {
        return self.kind == T.kind();
    }

    pub fn as(self: *@This(), comptime T: type) *T {
        std.debug.assert(self.kind == T.kind());
        return T.fromObject(self);
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        switch (self.kind) {
            .obj_string => {
                const string = self.as(ObjectString);
                string.deinit(allocator);
            }
        }
    }

    pub fn format(self: *@This(), writer: anytype) !void {
        try writer.print("{s}: ", .{@tagName(self.kind)});
        switch (self.kind) {
            .obj_string => try self.as(ObjectString).format(writer),
        }
    }
};

pub fn hashString(key: []const u8) u32 {
    var hash: u32 = 2166136261;

    for (key) |char| {
        hash ^= char;
        hash *%= 16777619;
    }

    return hash;
}

pub const ObjectString = struct {
    object: Object,
    chars: []const u8,
    hash: u32,

    pub fn kind() ObjectType {
        return .obj_string;
    }

    pub fn asObject(self: *@This()) *Object {
        return &self.object;
    }

    pub fn fromObject(object: *Object) *ObjectString {
        std.debug.assert(object.kind == .obj_string);
        return @alignCast(@fieldParentPtr("object", object));
    }

    pub fn copy(slice: []const u8, allocator: std.mem.Allocator) !*ObjectString {
        var new = try allocator.create(ObjectString);
        new.object.kind = .obj_string;
        new.object.next = null;
        new.chars = try allocator.dupe(u8, slice);
        new.hash = hashString(slice);
        return new;
    }

    pub fn take(slice: []const u8, allocator: std.mem.Allocator) !*ObjectString {
        var new = try allocator.create(ObjectString);
        new.object.kind = .obj_string;
        new.object.next = null;
        new.chars = slice;
        new.hash = hashString(slice);
        return new;
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.chars);
        allocator.destroy(self);
    }

    pub fn format(self: @This(), writer: anytype) !void {
        try writer.print("{s}", .{self.chars});
    }
};
