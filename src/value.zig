const std = @import("std");
const object_mod = @import("object.zig");
const Object = object_mod.Object;
const ObjectString = object_mod.ObjectString;

pub const ValueType = enum {
    val_bool,
    val_nil,
    val_number,
    val_obj,
};

pub const Value = union(ValueType) {
    val_bool: bool,
    val_nil,
    val_number: f64,
    val_obj: *Object,

    pub fn fromBool(v: bool) Value {
        return .{ .val_bool = v };
    }

    pub fn asBool(self: @This()) bool {
        return self.val_bool;
    }

    pub fn isBool(self: @This()) bool {
        return std.meta.activeTag(self) == .val_bool;
    }

    pub fn fromNumber(v: f64) Value {
        return .{ .val_number = v };
    }

    pub fn asNumber(self: @This()) f64 {
        return self.val_number;
    }

    pub fn isNumber(self: @This()) bool {
        return std.meta.activeTag(self) == .val_number;
    }

    pub fn fromObject(v: *Object) Value {
        return .{ .val_obj = v };
    }

    pub fn asObject(self: @This()) *Object {
        return self.val_obj;
    }

    pub fn isObject(self: @This()) bool {
        return std.meta.activeTag(self) == .val_obj;
    }

    pub fn isString(self: @This()) bool {
        return self.isObject() and self.asObject().isA(ObjectString);
    }

    pub fn asString(self: @This()) *ObjectString {
        std.debug.assert(self.isObject());
        return ObjectString.fromObject(self.asObject());
    }

    pub fn asStringSlice(self: @This()) []const u8 {
        const object_string = self.asString();
        return object_string.chars;
    }

    pub fn fromNil() Value {
        return .val_nil;
    }

    pub fn isNil(self: @This()) bool {
        return std.meta.activeTag(self) == .val_nil;
    }

    pub fn eq(lhs: Value, rhs: Value) bool {
        if (std.meta.activeTag(lhs) != std.meta.activeTag(rhs)) {
            return false;
        }

        switch (std.meta.activeTag(lhs)) {
            ValueType.val_nil => return true,
            ValueType.val_bool => return lhs.asBool() == rhs.asBool(),
            ValueType.val_number => return lhs.asNumber() == rhs.asNumber(),
            ValueType.val_obj => {
                const a = lhs.asObject().as(ObjectString);
                const b = rhs.asObject().as(ObjectString);
                return std.mem.eql(u8, a.chars, b.chars);
            },
        }
    }

    pub fn isFalsey(self: @This()) bool {
        return self.isNil() or (self.isBool() and !self.asBool());
    }

    pub fn format(self: Value, writer: anytype) !void {
        switch (self) {
            .val_number => |n| try writer.print("{}", .{n}),
            .val_bool => |b| try writer.print("{}", .{b}),
            .val_obj => |o| try writer.print("{f}", .{o}),
            .val_nil => try writer.print("nil", .{}),
        }
    }
};
