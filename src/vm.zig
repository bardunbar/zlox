const std = @import("std");

const debug = @import("debug.zig");

const chunk_mod = @import("chunk.zig");
const Chunk = chunk_mod.Chunk;
const OpCode = chunk_mod.OpCode;

const value_mod = @import("value.zig");
const Value = value_mod.Value;

const compiler = @import("compiler.zig");

const common = @import("common.zig");

var vm = VirtualMachine.init();

const stack_max = 256;

const VirtualMachine = struct {
    chunk: *Chunk,
    ip: [*]u8,
    stack: [stack_max]Value,
    stack_top: usize,
    allocator: std.mem.Allocator,

    fn init() @This() {
        return .{
            .chunk = undefined,
            .ip = undefined,
            .stack = [_]Value{Value.nil()} ** stack_max,
            .stack_top = 0,
            .allocator = undefined,
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

pub fn init(allocator: std.mem.Allocator) void {
    vm.allocator = allocator;
    resetStack();
}

pub fn deinit() void {}

fn resetStack() void {
    vm.stack_top = 0;
}

pub fn runtimeError(comptime format: []const u8, args: anytype) void {
    std.log.err(format, args);

    const instruction = vm.ip - vm.chunk.code.ptr - 1;
    const line = vm.chunk.lines[instruction];
    std.log.err("[line {}] in script.", .{line});
}

pub fn push(value: Value) void {
    vm.stack[vm.stack_top] = value;
    vm.stack_top += 1;
}

pub fn pop() Value {
    vm.stack_top -= 1;
    return vm.stack[vm.stack_top];
}

pub fn peek(distance: usize) Value {
    return vm.stack[vm.stack_top - 1 - distance];
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
    var chunk = Chunk.init(vm.allocator) catch |err| {
        std.log.err("Memory error: {}\n", .{err});
        return InterpretError.InterpretCompileError;
    };
    defer chunk.deinit();

    try compiler.compile(source, &chunk);

    vm.chunk = &chunk;
    vm.ip = vm.chunk.code.ptr;

    try run();
}

fn run() InterpretError!void {
    std.debug.print("== Run ==\n", .{});

    while (true) {
        if (comptime common.enable_debug_trace) {
            std.debug.print("stack     ", .{});
            for (0..vm.stack_top) |i| {
                std.debug.print("[ {f} ]", .{vm.stack[i]});
            }
            std.debug.print("\n", .{});

            _ = debug.disassembleInstruction(vm.chunk.*, vm.ip - vm.chunk.code.ptr);
        }

        const instruction: OpCode = @enumFromInt(readByte());

        switch (instruction) {
            OpCode.op_return => {
                std.debug.print("result: {}\n", .{pop()});
                return;
            },
            OpCode.op_constant => {
                push(readConstant(.short));
            },
            OpCode.op_constant_long => {
                push(readConstant(.long));
            },
            OpCode.op_negate => {
                if (!Value.isNumber(peek(0))) {
                    runtimeError("Operand must be a number.", .{});
                    return InterpretError.InterpretRuntimeError;
                }
                push(Value.fromNumber(-pop().asNumber()));
            },
            OpCode.op_add => {
                if (!Value.isNumber(peek(0)) or !Value.isNumber(peek(1))) {
                    runtimeError("Operands must be numbers.", .{});
                    return InterpretError.InterpretRuntimeError;
                }
                const b = pop().asNumber();
                const a = pop().asNumber();
                push(Value.fromNumber(a + b));
            },
            OpCode.op_subtract => {
                if (!Value.isNumber(peek(0)) or !Value.isNumber(peek(1))) {
                    runtimeError("Operands must be numbers.", .{});
                    return InterpretError.InterpretRuntimeError;
                }
                const b = pop().asNumber();
                const a = pop().asNumber();
                push(Value.fromNumber(a - b));
            },
            OpCode.op_multiply => {
                if (!Value.isNumber(peek(0)) or !Value.isNumber(peek(1))) {
                    runtimeError("Operands must be numbers.", .{});
                    return InterpretError.InterpretRuntimeError;
                }
                const b = pop().asNumber();
                const a = pop().asNumber();
                push(Value.fromNumber(a * b));
            },
            OpCode.op_divide => {
                if (!Value.isNumber(peek(0)) or !Value.isNumber(peek(1))) {
                    runtimeError("Operands must be numbers.", .{});
                    return InterpretError.InterpretRuntimeError;
                }
                const b = pop().asNumber();
                const a = pop().asNumber();
                push(Value.fromNumber(a / b));
            },
        }
    }
}
