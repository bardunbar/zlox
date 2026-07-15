const std = @import("std");

const mod_array = @import("array.zig");
const Array = mod_array.Array;

const mod_value = @import("value.zig");
const Value = mod_value.Value;

const ValueArray = Array(Value);

pub const OpCode = enum(u8) {
    op_constant,
    op_nil,
    op_true,
    op_false,
    op_equal,
    op_greater,
    op_less,
    op_constant_long,
    op_add,
    op_subtract,
    op_multiply,
    op_divide,
    op_not,
    op_negate,
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

    pub fn writeConstant(self: *@This(), value: Value, line: u32) !void {
        const index = try addConstant(self, value);

        // If the index fits in a u8 we can use a small constant
        if (index < std.math.maxInt(u8)) {
            const index_byte: u8 = @intCast(index);
            try writeChunk(self, OpCode.op_constant.as_byte(), line);
            try writeChunk(self, index_byte, line);
        } else if (index < std.math.maxInt(u24)) { // Otherwise we have to use a large constant
            const byte_low: u8 = @intCast(index & 0xF);
            const byte_middle: u8 = @intCast((index & 0xF0) >> 4);
            const byte_high: u8 = @intCast((index & 0xF00) >> 8);

            try writeChunk(self, OpCode.op_constant_long.as_byte(), line);
            try writeChunk(self, byte_high, line);
            try writeChunk(self, byte_middle, line);
            try writeChunk(self, byte_low, line);
        } else {
            return error.ContantIndexOverflow;
        }
    }

    pub fn writeLongConstant(self: *@This(), value: Value, line: u32) !void {
        const index = try addConstant(self, value);

        if (index < std.math.maxInt(u24)) {
            const byte_low: u8 = @intCast(index & 0xF);
            const byte_middle: u8 = @intCast((index & 0xF0) >> 4);
            const byte_high: u8 = @intCast((index & 0xF00) >> 8);

            try writeChunk(self, OpCode.op_constant_long.as_byte(), line);
            try writeChunk(self, byte_high, line);
            try writeChunk(self, byte_middle, line);
            try writeChunk(self, byte_low, line);
        } else {
            return error.ContantIndexOverflow;
        }
    }

    pub fn addConstant(self: *@This(), value: Value) !usize {
        try self.constants.append(value);
        return @intCast(self.constants.count - 1);
    }
};
