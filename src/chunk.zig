const std = @import("std");

const mod_array = @import("array.zig");
const Array = mod_array.Array;

const mod_value = @import("value.zig");
const Value = mod_value.Value;

const ValueArray = Array(Value);

pub const OpCode = enum(u8) {
    op_constant,
    op_return,

    pub fn as_byte(self: @This()) u8 {
        return @intFromEnum(self);
    }
};

pub const Chunk = struct {
    code: []u8,
    lines: []u32,
    constants: ValueArray,
    count: usize,
    capacity: usize, // These are probably not necessary thanks the the fat pointer slice
    allocator: std.mem.Allocator,

    pub fn init(a: std.mem.Allocator) !@This() {
        const initial_capacity = 8;
        return .{
            .code = try a.alloc(u8, initial_capacity),
            .lines = try a.alloc(u32, initial_capacity),
            .constants = try ValueArray.init(a),
            .count = 0,
            .capacity = initial_capacity,
            .allocator = a,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.code);
        self.allocator.free(self.lines);
        self.constants.deinit();
        self.code = undefined;
        self.count = 0;
        self.capacity = 0;
    }

    pub fn writeChunk(self: *@This(), byte: u8, line: u32) !void {
        if (self.capacity < self.count + 1) {
            self.capacity *= 2;
            self.code = try self.allocator.realloc(self.code, self.capacity);
            self.lines = try self.allocator.realloc(self.lines, self.capacity);
        }

        self.code[self.count] = byte;
        self.lines[self.count] = line;
        self.count += 1;
    }

    pub fn addConstant(self: *@This(), value: Value) !u8 {
        try self.constants.append(value);
        return @intCast(self.constants.count - 1);
    }
};
