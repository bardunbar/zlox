const std = @import("std");

const mod_chunk = @import("chunk.zig");
const Chunk = mod_chunk.Chunk;
const OpCode = mod_chunk.OpCode;

pub fn disassembleChunk(chunk: Chunk, name: []const u8) void {
    std.debug.print("== {s} ==\n", .{name});

    var offset: usize = 0;
    while (offset < chunk.count) {
        offset = disassembleInstruction(chunk, offset);
    }
}

pub fn disassembleInstruction(chunk: Chunk, offset: usize) usize {
    std.debug.print("{:0>4} ", .{offset});

    if (offset > 0 and chunk.lines[offset] == chunk.lines[offset - 1]) {
        std.debug.print("   | ", .{});
    } else {
        std.debug.print("{: >4} ", .{chunk.lines[offset]});
    }
    const instruction: OpCode = @enumFromInt(chunk.code[offset]);
    switch (instruction) {
        OpCode.op_constant,
        OpCode.op_define_global,
        OpCode.op_get_global,
        => {
            return constantInstruction(@tagName(instruction), chunk, offset);
        },
        OpCode.op_constant_long,
        OpCode.op_define_global_long,
        OpCode.op_get_global_long,
        => {
            return longConstantInstruction(@tagName(instruction), chunk, offset);
        },
        OpCode.op_return,
        OpCode.op_negate,
        OpCode.op_add,
        OpCode.op_subtract,
        OpCode.op_multiply,
        OpCode.op_divide,
        OpCode.op_nil,
        OpCode.op_true,
        OpCode.op_false,
        OpCode.op_not,
        OpCode.op_equal,
        OpCode.op_greater,
        OpCode.op_less,
        OpCode.op_print,
        OpCode.op_pop,
        => {
            return simpleInstruction(@tagName(instruction), offset);
        },
    }
}

fn simpleInstruction(name: []const u8, offset: usize) usize {
    std.debug.print("{s}\n", .{name});
    return offset + 1;
}

fn constantInstruction(name: []const u8, chunk: Chunk, offset: usize) usize {
    const constant_idx = chunk.code[offset + 1];
    const constant_value = chunk.constants.data[constant_idx];
    std.debug.print("{s: <16} {:0>4} '{f}'\n", .{ name, constant_idx, constant_value });
    return offset + 2;
}

fn longConstantInstruction(name: []const u8, chunk: Chunk, offset: usize) usize {
    const idx_high = @as(usize, @intCast(chunk.code[offset + 1]));
    const idx_middle = @as(usize, @intCast(chunk.code[offset + 2]));
    const idx_low = @as(usize, @intCast(chunk.code[offset + 3]));

    const idx = (idx_high << 8) + (idx_middle << 4) + idx_low;
    const constant_value = chunk.constants.data[idx];

    std.debug.print("{s: <16} {:0>4} '{f}'\n", .{ name, idx, constant_value });

    return offset + 4;
}
