const std = @import("std");
const Io = std.Io;

const chunk = @import("chunk.zig");
const debug = @import("debug.zig");
const vm = @import("vm.zig");

pub fn main(init: std.process.Init) !void {
    // Prints to stderr, unbuffered, ignoring potential errors.
    std.debug.print("Running zLox.\n", .{});

    // This is appropriate for anything that lives as long as the process.
    const arena: std.mem.Allocator = init.arena.allocator();

    // Accessing command line arguments:
    const args = try init.minimal.args.toSlice(arena);
    for (args) |arg| {
        std.log.info("arg: {s}", .{arg});
    }

    vm.init();
    defer vm.deinit();

    var c = try chunk.Chunk.init(init.gpa);
    defer c.deinit();

    // 1 + 2 * 3 - 4 / -5 = 7.8
    try c.writeConstant(1, 123);
    try c.writeConstant(2, 123);
    try c.writeConstant(3, 123);
    try c.writeChunk(chunk.OpCode.op_multiply.as_byte(), 123);
    try c.writeChunk(chunk.OpCode.op_add.as_byte(), 123);

    try c.writeConstant(4, 123);
    try c.writeConstant(5, 123);
    try c.writeChunk(chunk.OpCode.op_negate.as_byte(), 123);
    try c.writeChunk(chunk.OpCode.op_divide.as_byte(), 123);
    try c.writeChunk(chunk.OpCode.op_subtract.as_byte(), 123);

    try c.writeChunk(chunk.OpCode.op_return.as_byte(), 123);

    _ = vm.interpret(&c);
}
