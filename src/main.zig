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

    try c.writeConstant(1.2, 123);
    try c.writeLongConstant(2.4, 123);
    try c.writeChunk(chunk.OpCode.op_return.as_byte(), 123);
    //debug.disassembleChunk(c, "test chunk");

    _ = vm.interpret(&c);
}
