const std = @import("std");

//pub const Value = f64;

pub const ValueType = enum {
    val_bool,
    val_nil,
    val_number,
};

pub const Value = union(ValueType) {
    val_bool: bool,
    val_nil,
    val_number: f64,

    pub fn asBool(self: @This()) bool {
        return self.val_bool;
    }

    pub fn isBool(self: @This()) bool {
        return std.meta.activeTag(self) == .val_bool;
    }

    pub fn asNumber(self: @This()) f64 {
        return self.val_number;
    }

    pub fn isNumber(self: @This()) bool {
        return std.meta.activeTag(self) == .val_number;
    }

    pub fn isNil(self: @This()) bool {
        return std.meta.activeTag(self) == .val_nil;
    }

    pub fn fromBool(v: bool) Value {
        return .{ .val_bool = v };
    }

    pub fn fromNumber(v: f64) Value {
        return .{ .val_number = v };
    }

    pub fn nil() Value {
        return .val_nil;
    }

    pub fn format(self: Value, writer: anytype) !void {
        switch (self) {
            .val_number => |n| try writer.print("{}", .{n}),
            .val_bool => |b| try writer.print("{}", .{b}),
            .val_nil => try writer.print("nil", .{}),
        }
    }
};
