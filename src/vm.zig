const std = @import("std");

const debug = @import("debug.zig");

const chunk_mod = @import("chunk.zig");
const Chunk = chunk_mod.Chunk;
const OpCode = chunk_mod.OpCode;

const value_mod = @import("value.zig");
const Value = value_mod.Value;

var vm = VirtualMachine.init();

const VirtualMachine = struct {
    chunk: *Chunk,
    ip: [*]u8,

    fn init() @This() {
        return .{
            .chunk = undefined,
            .ip = undefined,
        };
    }
};

pub const InterpretResult = enum {
    interpret_ok,
    interpret_compile_error,
    interpret_runtime_error,
};

pub fn init() void {}

pub fn deinit() void {}

fn readByte() u8 {
    const result = vm.ip[0];
    vm.ip += 1;
    return result;
}

fn readConstant(mode: enum { long, short }) Value {
    return switch (mode) {
        .long => long: {
            const idx_high = @as(usize, @intCast(readByte()));
            const idx_middle = @as(usize, @intCast(readByte()));
            const idx_low = @as(usize, @intCast(readByte()));

            const idx = (idx_high << 8) + (idx_middle << 4) + idx_low;
            break :long vm.chunk.constants.data[idx];
        },
        .short => vm.chunk.constants.data[readByte()],
    };
}

pub fn interpret(chunk: *Chunk) InterpretResult {
    vm.chunk = chunk;
    vm.ip = chunk.code.ptr;

    return run();
}

const enable_debug_trace: bool = true;

fn run() InterpretResult {
    while (true) {
        if (comptime enable_debug_trace) {
            _ = debug.disassembleInstruction(vm.chunk.*, vm.ip - vm.chunk.code.ptr);
        }

        const instruction: OpCode = @enumFromInt(readByte());

        switch (instruction) {
            OpCode.op_return => return InterpretResult.interpret_ok,
            OpCode.op_constant => {
                std.debug.print("{}\n", .{readConstant(.short)});
            },
            OpCode.op_constant_long => {
                std.debug.print("{}\n", .{readConstant(.long)});
            },
        }
    }
}
