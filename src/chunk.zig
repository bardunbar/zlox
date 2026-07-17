const std = @import("std");

const mod_array = @import("array.zig");
const Array = mod_array.Array;

const mod_value = @import("value.zig");
const Value = mod_value.Value;

const ValueArray = Array(Value);

pub const ConstantIndexTag = enum {
    short,
    long,
    invalid,
};

pub const ConstantIndex = union(ConstantIndexTag) {
    short: u8,
    long: u24,
    invalid,

    pub fn init(index: usize) @This() {
        if (index < std.math.maxInt(u8)) {
            return .{
                .short = @intCast(index),
            };
        } else if (index < std.math.maxInt(u24)) {
            return .{ .long = @intCast(index) };
        } else {
            return .invalid;
        }
    }
};

pub const OpCode = enum(u8) {
    op_constant,
    op_nil,
    op_true,
    op_false,
    op_pop,
    op_define_global,
    op_define_global_long,
    op_get_global,
    op_get_global_long,
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
    op_print,
    op_return,

    pub fn asByte(self: @This()) u8 {
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

        switch (index) {
            .short => |i| {
                try writeChunk(self, OpCode.op_constant.asByte(), line);
                try writeChunk(self, i, line);
            },
            .long => |i| {
                const byte_low: u8 = @intCast(i & 0xF);
                const byte_middle: u8 = @intCast((i & 0xF0) >> 4);
                const byte_high: u8 = @intCast((i & 0xF00) >> 8);

                try writeChunk(self, OpCode.op_constant_long.asByte(), line);
                try writeChunk(self, byte_high, line);
                try writeChunk(self, byte_middle, line);
                try writeChunk(self, byte_low, line);
            },
            .invalid => {
                return error.ContantIndexOverflow;
            }
        }
    }

    pub fn addConstant(self: *@This(), value: Value) !ConstantIndex {
        try self.constants.append(value);
        return ConstantIndex.init(self.constants.count - 1);
    }

    pub fn addLongConstant(self: *@This(), value: Value) !ConstantIndex {
        try self.constants.append(value);
        const index = self.constants.count - 1;
        if (index < std.math.maxInt(u24)) {
            return .{ .long = @intCast(index) };
        } else {
            return .invalid;
        }
    }
};
