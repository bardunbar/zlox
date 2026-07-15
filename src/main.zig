const builtin = @import("builtin");
const std = @import("std");
const Io = std.Io;

const chunk = @import("chunk.zig");
const debug = @import("debug.zig");

const vm = @import("vm.zig");
const InterpretError = vm.InterpretError;

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

    vm.init(init.gpa);
    defer vm.deinit();

    if (args.len == 1) {
        try repl(init.io);
    } else if (args.len == 2) {
        try runFile(args[1], init.io, init.gpa);
    } else {
        std.log.err("Usage: zlox [path]\n", .{});
    }
}

fn repl(io: std.Io) !void {
    var buf: [1024]u8 = undefined;

    var stdin = std.Io.File.stdin().reader(io, &buf);

    //const line = try stdin.interface.takeDelimiterExclusive('\n');

    while (true) {
        std.debug.print("> ", .{});

        var line = try stdin.interface.takeDelimiter('\n') orelse {
            std.debug.print("\n", .{});
            break;
        };

        if (line.len > 0) {
            if (comptime builtin.target.os.tag == .windows) {
                line = line[0 .. line.len - 1];
            }

            vm.interpret(line) catch |err| {
                std.log.err("Encountered error: {}", .{err});
                return;
            };
        }
    }
}

fn runFile(path: []const u8, io: std.Io, allocator: std.mem.Allocator) !void {
    // get the current working directory
    const cwd = std.Io.Dir.cwd();
    const file = cwd.openFile(io, path, .{ .mode = .read_only }) catch |err| {
        std.log.err("Unable to open file: {s}. Reason: {}\n", .{ path, err });
        return;
    };
    defer file.close(io);

    const file_size = try file.length(io);
    std.debug.print("Found file {s}. Size is {}\n", .{ path, file_size });

    const buffer = try allocator.alloc(u8, 4096);
    defer allocator.free(buffer);

    var file_reader = file.reader(io, buffer);

    const file_reader_buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(file_reader_buffer);

    file_reader.interface.readSliceAll(file_reader_buffer) catch |err| {
        std.log.err("Read failed: {}\n", .{err});
        return err;
    };

    vm.interpret(file_reader_buffer) catch |err| {
        std.log.err("Encountered error: {}\n", .{err});
    };
}
