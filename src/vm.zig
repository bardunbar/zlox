const std = @import("std");

const debug = @import("debug.zig");

const chunk_mod = @import("chunk.zig");
const Chunk = chunk_mod.Chunk;
const OpCode = chunk_mod.OpCode;

const value_mod = @import("value.zig");
const Value = value_mod.Value;

const object_mod = @import("object.zig");
const Object = object_mod.Object;
const ObjectString = object_mod.ObjectString;

const compiler = @import("compiler.zig");

const memory = @import("memory.zig");
const Table = @import("table.zig");
const common = @import("common.zig");

var vm: VirtualMachine = undefined;

const stack_max = 256;

const VirtualMachine = struct {
    chunk: *Chunk,
    ip: [*]u8,
    stack: [stack_max]Value,
    stack_top: usize,
    manager: memory.Manager,
    globals: Table,

    fn init(allocator: std.mem.Allocator) !@This() {
        return .{
            .chunk = undefined,
            .ip = undefined,
            .stack = [_]Value{Value.fromNil()} ** stack_max,
            .stack_top = 0,
            .manager = try memory.Manager.init(allocator),
            .globals = try Table.init(allocator),
        };
    }

    fn deinit(self: *@This()) void {
        self.manager.deinit();
        self.globals.deinit();
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

pub fn init(allocator: std.mem.Allocator) !void {
    vm = try VirtualMachine.init(allocator);
    resetStack();
}

pub fn deinit() void {
    vm.deinit();
}

pub fn manager() *memory.Manager {
    return &vm.manager;
}

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

pub fn concatenate() !void {
    const b = pop().asString();
    const a = pop().asString();

    const object = try vm.manager.concat(a.chars, b.chars);
    push(Value.fromObject(object));
}

pub fn interpret(source: []const u8) InterpretError!void {
    var chunk = Chunk.init(vm.manager.allocator) catch |err| {
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
                return;
            },
            OpCode.op_constant => {
                push(readConstant(.short));
            },
            OpCode.op_constant_long => {
                push(readConstant(.long));
            },
            OpCode.op_nil => {
                push(Value.fromNil());
            },
            OpCode.op_true => {
                push(Value.fromBool(true));
            },
            OpCode.op_false => {
                push(Value.fromBool(false));
            },
            OpCode.op_pop => {
                _ = pop();
            },
            OpCode.op_define_global => {
                const name = readConstant(.short).asString();
                _ = vm.globals.set(name, peek(0)) catch |err| {
                    runtimeError("{s}", .{@errorName(err)});
                    return InterpretError.InterpretRuntimeError;
                };
                _ = pop();
            },
            OpCode.op_define_global_long => {
                const name = readConstant(.long).asString();
                _ = vm.globals.set(name, peek(0)) catch |err| {
                    runtimeError("{s}", .{@errorName(err)});
                    return InterpretError.InterpretRuntimeError;
                };
                _ = pop();
            },
            OpCode.op_get_global => {
                const name = readConstant(.short).asString();
                var value: Value = undefined;
                if (!vm.globals.get(name, &value)) {
                    runtimeError("Undefined variable '{s}'", .{name.chars});
                    return InterpretError.InterpretRuntimeError;
                }
                push(value);
            },
            OpCode.op_get_global_long => {
                const name = readConstant(.long).asString();
                var value: Value = undefined;
                if (!vm.globals.get(name, &value)) {
                    runtimeError("Undefined variable '{s}'", .{name.chars});
                    return InterpretError.InterpretRuntimeError;
                }
                push(value);
            },
            OpCode.op_equal => {
                const b = pop();
                const a = pop();

                push(Value.fromBool(Value.eq(a, b)));
            },
            OpCode.op_negate => {
                if (!Value.isNumber(peek(0))) {
                    runtimeError("Operand must be a number.", .{});
                    return InterpretError.InterpretRuntimeError;
                }
                push(Value.fromNumber(-pop().asNumber()));
            },
            OpCode.op_greater => {
                if (!Value.isNumber(peek(0)) or !Value.isNumber(peek(1))) {
                    runtimeError("Operands must be numbers.", .{});
                    return InterpretError.InterpretRuntimeError;
                }
                const b = pop().asNumber();
                const a = pop().asNumber();
                push(Value.fromBool(a > b));
            },
            OpCode.op_less => {
                if (!Value.isNumber(peek(0)) or !Value.isNumber(peek(1))) {
                    runtimeError("Operands must be numbers.", .{});
                    return InterpretError.InterpretRuntimeError;
                }
                const b = pop().asNumber();
                const a = pop().asNumber();
                push(Value.fromBool(a < b));
            },
            OpCode.op_add => {
                if (Value.isString(peek(0)) and Value.isString(peek(1))) {
                    concatenate() catch |err| {
                        runtimeError("{}", .{err});
                        return InterpretError.InterpretRuntimeError;
                    };
                } else if (Value.isNumber(peek(0)) and Value.isNumber(peek(1))) {
                    const b = pop().asNumber();
                    const a = pop().asNumber();
                    push(Value.fromNumber(a + b));
                } else {
                    runtimeError("Operands must be numbers.", .{});
                    return InterpretError.InterpretRuntimeError;
                }
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
            OpCode.op_not => {
                push(Value.fromBool(pop().isFalsey()));
            },
            OpCode.op_print => {
                std.debug.print("{f}\n", .{pop()});
            }
        }
    }
}
