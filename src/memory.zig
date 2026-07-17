const std = @import("std");
const object_mod = @import("object.zig");
const Object = object_mod.Object;
const ObjectString = object_mod.ObjectString;

const Table = @import("table.zig");

const value_mod = @import("value.zig");
const Value = value_mod.Value;

pub const Manager = struct {
    objects: ?*Object,
    strings: Table,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !@This() {
        return .{
            .objects = null,
            .strings = try Table.init(allocator),
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
        self.strings.deinit();
    }

    pub fn copy(self: *@This(), str: []const u8) !*Object {
        const hash = object_mod.hashString(str);
        const interned = self.strings.findString(str, hash);
        if (interned) |string| {
            return string.asObject();
        }

        var new = try ObjectString.copy(str, self.allocator);
        new.object.next = self.objects;
        self.objects = &new.object;
        _ = try self.strings.set(new, Value.fromNil());
        return &new.object;
    }

    pub fn concat(self: *@This(), a: []const u8, b: []const u8) !*Object {
        const result = try std.mem.concat(self.allocator, u8, &[_][]const u8{ a, b });
        const hash = object_mod.hashString(result);
        const interned = self.strings.findString(result, hash);
        if (interned) |string| {
            self.allocator.free(result);
            return string.asObject();
        }

        var new = try ObjectString.take(result, self.allocator);
        new.object.next = self.objects;
        self.objects = &new.object;
        _ = try self.strings.set(new, Value.fromNil());
        return &new.object;
    }
};
