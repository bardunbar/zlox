const std = @import("std");
const vm = @import("vm.zig");
const InterpretError = vm.InterpretError;

const scanner = @import("scanner.zig");
const TokenType = scanner.TokenType;

pub fn compile(source: []const u8) InterpretError!void {
    scanner.init(source);

    var line: u32 = std.math.maxInt(u32);

    while (true) {
        const token = scanner.nextToken();

        if (token.line != line) {
            std.debug.print("{: >4} ", .{token.line});
            line = token.line;
        } else {
            std.debug.print("   | ", .{});
        }
        std.debug.print("{s: >15} {s}\n", .{ @tagName(token.kind), token.data });

        if (token.kind == TokenType.k_eof) {
            break;
        }
    }
}
