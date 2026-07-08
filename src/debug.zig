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

fn disassembleInstruction(chunk: Chunk, offset: usize) usize {
    std.debug.print("{:0>4} ", .{offset});

    if (offset > 0 and chunk.lines[offset] == chunk.lines[offset - 1]) {
        std.debug.print("   | ", .{});
    } else {
        std.debug.print("{: >4} ", .{chunk.lines[offset]});
    }
    const instruction: OpCode = @enumFromInt(chunk.code[offset]);
    switch (instruction) {
        OpCode.op_constant => {
            return constantInstruction(@tagName(OpCode.op_constant), chunk, offset);
        },
        OpCode.op_return => {
            return simpleInstruction(@tagName(OpCode.op_return), offset);
        },
    }
}

fn simpleInstruction(name: []const u8, offset: usize) usize {
    std.debug.print("{s}", .{name});
    return offset + 1;
}

fn constantInstruction(name: []const u8, chunk: Chunk, offset: usize) usize {
    const constant = chunk.code[offset + 1];
    const constant_value = chunk.constants.data[constant];
    std.debug.print("{s: <16} {:0>4} '{}'\n", .{ name, constant, constant_value });
    return offset + 2;
}
