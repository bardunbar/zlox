const std = @import("std");

const debug = @import("debug.zig");

const chunk_mod = @import("chunk.zig");
const Chunk = chunk_mod.Chunk;
const OpCode = chunk_mod.OpCode;

const value_mod = @import("value.zig");
const Value = value_mod.Value;

const compiler = @import("compiler.zig");

var vm = VirtualMachine.init();

const stack_max = 256;

const VirtualMachine = struct {
    chunk: *Chunk,
    ip: [*]u8,
    stack: [stack_max]Value,
    stack_top: usize,

    fn init() @This() {
        return .{
            .chunk = undefined,
            .ip = undefined,
            .stack = std.mem.zeroes([256]Value),
            .stack_top = 0,
        };
    }
};

pub const InterpretError = error{
    InterpretCompileError,
    InterpretRuntimeError,
};

pub const InterpretResult = enum {
    interpret_ok,
    interpret_compile_error,
    interpret_runtime_error,
};

pub fn init() void {
    vm.stack_top = 0;
}

pub fn deinit() void {}

pub fn push(value: Value) void {
    vm.stack[vm.stack_top] = value;
    vm.stack_top += 1;
}

pub fn pop() Value {
    vm.stack_top -= 1;
    return vm.stack[vm.stack_top];
}

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

pub fn interpret(source: []const u8) InterpretError!void {
    try compiler.compile(source);
}

const enable_debug_trace: bool = true;

fn run() InterpretError!void {
    while (true) {
        if (comptime enable_debug_trace) {
            std.debug.print("          ", .{});
            for (0..vm.stack_top) |i| {
                std.debug.print("[ {} ]", .{vm.stack[i]});
            }
            std.debug.print("\n", .{});

            _ = debug.disassembleInstruction(vm.chunk.*, vm.ip - vm.chunk.code.ptr);
        }

        const instruction: OpCode = @enumFromInt(readByte());

        switch (instruction) {
            OpCode.op_return => {
                std.debug.print("{}\n", .{pop()});
                return;
            },
            OpCode.op_constant => {
                push(readConstant(.short));
            },
            OpCode.op_constant_long => {
                push(readConstant(.long));
            },
            OpCode.op_negate => {
                push(-pop());
            },
            OpCode.op_add => {
                const b = pop();
                const a = pop();
                push(a + b);
            },
            OpCode.op_subtract => {
                const b = pop();
                const a = pop();
                push(a - b);
            },
            OpCode.op_multiply => {
                const b = pop();
                const a = pop();
                push(a * b);
            },
            OpCode.op_divide => {
                const b = pop();
                const a = pop();
                push(a / b);
            },
        }
    }
}
