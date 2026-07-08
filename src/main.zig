const std = @import("std");
const Io = std.Io;

const chunk = @import("chunk.zig");
const debug = @import("debug.zig");

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

    var c = try chunk.Chunk.init(init.gpa);
    const constant = try c.addConstant(1.2);
    try c.writeChunk(chunk.OpCode.op_constant.as_byte(), 123);
    try c.writeChunk(constant, 123);
    try c.writeChunk(chunk.OpCode.op_return.as_byte(), 123);
    debug.disassembleChunk(c, "test chunk");

    c.deinit();
}
