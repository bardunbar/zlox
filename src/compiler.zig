const std = @import("std");
const vm = @import("vm.zig");
const InterpretError = vm.InterpretError;

const chunk_mod = @import("chunk.zig");
const Chunk = chunk_mod.Chunk;
const OpCode = chunk_mod.OpCode;

const scanner = @import("scanner.zig");
const Token = scanner.Token;
const TokenType = scanner.TokenType;

const value_mod = @import("value.zig");
const Value = value_mod.Value;

const common = @import("common.zig");
const debug = @import("debug.zig");

var parser: Parser = .{
    .current = undefined,
    .previous = undefined,
    .had_error = false,
    .panic_mode = false,
};
var compiling_chunk: *Chunk = undefined;

const Parser = struct {
    current: Token,
    previous: Token,
    had_error: bool,
    panic_mode: bool,
};

const Precedence = enum {
    none,
    assignment,
    bool_or,
    bool_and,
    equality,
    comparison,
    term,
    factor,
    unary,
    call,
    primary,
};

const ParseFn = *const fn () anyerror!void;

const ParseRule = struct {
    prefix: ?ParseFn = null,
    infix: ?ParseFn = null,
    precedence: Precedence = Precedence.none,
};

const rules = std.enums.directEnumArray(TokenType, ParseRule, 0, .{
    .left_paren = .{ .prefix = grouping },
    .right_paren = .{},
    .left_brace = .{},
    .right_brace = .{},
    .comma = .{},
    .dot = .{},
    .minus = .{ .prefix = unary, .infix = binary, .precedence = Precedence.term },
    .plus = .{ .infix = binary, .precedence = Precedence.term },
    .semicolon = .{},
    .slash = .{ .infix = binary, .precedence = Precedence.factor },
    .star = .{ .infix = binary, .precedence = Precedence.factor },
    .bang = .{},
    .bang_equal = .{},
    .equal = .{},
    .equal_equal = .{},
    .greater = .{},
    .greater_equal = .{},
    .less = .{},
    .less_equal = .{},
    .identifier = .{},
    .string = .{},
    .number = .{ .prefix = number },
    .k_and = .{},
    .k_class = .{},
    .k_else = .{},
    .k_false = .{},
    .k_for = .{},
    .k_fun = .{},
    .k_if = .{},
    .k_nil = .{},
    .k_or = .{},
    .k_print = .{},
    .k_return = .{},
    .k_super = .{},
    .k_this = .{},
    .k_true = .{},
    .k_var = .{},
    .k_while = .{},
    .k_error = .{},
    .k_eof = .{},
});

pub fn compile(source: []const u8, chunk: *Chunk) InterpretError!void {
    scanner.init(source);
    compiling_chunk = chunk;

    parser.had_error = false;
    parser.panic_mode = false;

    advance();

    expression();

    consume(TokenType.k_eof, "Expect end of expression.");

    endCompiler() catch |err| {
        errorAtCurrent(@errorName(err));
    };

    if (parser.had_error) {
        return InterpretError.InterpretCompileError;
    }
}

fn advance() void {
    parser.previous = parser.current;

    while (true) {
        parser.current = scanner.nextToken();
        if (parser.current.kind != TokenType.k_error) {
            break;
        }
    }
}

fn consume(kind: TokenType, message: []const u8) void {
    if (parser.current.kind == kind) {
        advance();
        return;
    }

    errorAtCurrent(message);
}

fn emitByte(byte: u8) !void {
    try currentChunk().writeChunk(byte, parser.previous.line);
}

fn emitBytes(bytes: []const u8) !void {
    for (bytes) |byte| {
        try emitByte(byte);
    }
}

fn emitReturn() !void {
    try emitByte(OpCode.op_return.as_byte());
}

fn emitConstant(value: Value) !void {
    try currentChunk().writeConstant(value, parser.previous.line);
}

fn endCompiler() !void {
    try emitReturn();

    if (comptime common.enable_print_code) {
        if (!parser.had_error) {
            debug.disassembleChunk(currentChunk().*, "code");
        }
    }
}

fn binary() !void {
    const operator_type = parser.previous.kind;
    const rule = getRule(operator_type);
    parsePrecedence(@enumFromInt(@intFromEnum(rule.precedence) + 1));

    switch (operator_type) {
        TokenType.plus => try emitByte(OpCode.op_add.as_byte()),
        TokenType.minus => try emitByte(OpCode.op_subtract.as_byte()),
        TokenType.star => try emitByte(OpCode.op_multiply.as_byte()),
        TokenType.slash => try emitByte(OpCode.op_divide.as_byte()),
        else => unreachable,
    }
}

fn grouping() !void {
    expression();
    consume(TokenType.right_paren, "Expect ')' after expression.");
}

fn number() !void {
    const double = try std.fmt.parseFloat(f64, parser.previous.data);

    try emitConstant(Value.fromNumber(double));
}

fn unary() !void {
    const token_kind = parser.previous.kind;

    parsePrecedence(Precedence.unary);

    switch (token_kind) {
        TokenType.minus => try emitByte(OpCode.op_negate.as_byte()),
        else => unreachable,
    }
}

fn parsePrecedence(precedence: Precedence) void {
    advance();
    //std.debug.print("Parsing Precedence: {s}\n", .{@tagName(parser.previous.kind)});

    const prefix_option = getRule(parser.previous.kind).prefix;
    if (prefix_option) |prefix| {
        prefix() catch |err| {
            errorAtPrevious(@errorName(err));
            return;
        };
    } else {
        errorAtPrevious("Expect expression.");
        return;
    }

    const precedence_value = @intFromEnum(precedence);

    while (precedence_value <= @intFromEnum(getRule(parser.current.kind).precedence)) {
        advance();
        const infix_option = getRule(parser.previous.kind).infix;
        if (infix_option) |infix| {
            infix() catch |err| {
                errorAtPrevious(@errorName(err));
            };
        }
    }
}

fn getRule(kind: TokenType) *const ParseRule {
    return &rules[@as(usize, @intFromEnum(kind))];
}

fn expression() void {
    parsePrecedence(Precedence.assignment);
}

fn currentChunk() *Chunk {
    return compiling_chunk;
}

fn errorAtCurrent(message: []const u8) void {
    errorAt(&parser.current, message);
}

fn errorAtPrevious(message: []const u8) void {
    errorAt(&parser.previous, message);
}

fn errorAt(token: *Token, message: []const u8) void {
    parser.panic_mode = true;
    parser.had_error = true;

    var buf: [256]u8 = undefined;
    var swap: [256]u8 = undefined;
    var err_msg = std.fmt.bufPrint(&buf, "[line {}] Error", .{token.line}) catch |err| {
        std.log.err("Unable to print error: {s}", .{@errorName(err)});
        return;
    };

    switch (token.kind) {
        TokenType.k_eof => err_msg = std.fmt.bufPrint(&swap, "{s} at end", .{err_msg}) catch |err| {
            std.log.err("Unable to print error: {s}", .{@errorName(err)});
            return;
        },
        TokenType.k_error => {},
        else => err_msg = std.fmt.bufPrint(&swap, "{s} at '{s}'", .{ err_msg, token.data }) catch |err| {
            std.log.err("Unable to print error: {s}", .{@errorName(err)});
            return;
        },
    }

    std.log.err("{s}: {s}", .{ err_msg, message });
}
