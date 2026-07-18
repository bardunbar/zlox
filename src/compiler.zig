const std = @import("std");
const vm = @import("vm.zig");
const InterpretError = vm.InterpretError;

const chunk_mod = @import("chunk.zig");
const Chunk = chunk_mod.Chunk;
const OpCode = chunk_mod.OpCode;
const ConstantIndex = chunk_mod.ConstantIndex;

const scanner = @import("scanner.zig");
const Token = scanner.Token;
const TokenType = scanner.TokenType;

const value_mod = @import("value.zig");
const Value = value_mod.Value;

const object_mod = @import("object.zig");
const Object = object_mod.Object;
const ObjectString = object_mod.ObjectString;

const memory = @import("memory.zig");

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

const ParseFn = *const fn (can_assign: bool) anyerror!void;

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
    .bang = .{ .prefix = unary },
    .bang_equal = .{ .infix = binary, .precedence = Precedence.equality },
    .equal = .{},
    .equal_equal = .{ .infix = binary, .precedence = Precedence.equality },
    .greater = .{ .infix = binary, .precedence = Precedence.comparison },
    .greater_equal = .{ .infix = binary, .precedence = Precedence.comparison },
    .less = .{ .infix = binary, .precedence = Precedence.comparison },
    .less_equal = .{ .infix = binary, .precedence = Precedence.comparison },
    .identifier = .{ .prefix = variable },
    .string = .{ .prefix = string },
    .number = .{ .prefix = number },
    .k_and = .{},
    .k_class = .{},
    .k_else = .{},
    .k_false = .{ .prefix = literal },
    .k_for = .{},
    .k_fun = .{},
    .k_if = .{},
    .k_nil = .{ .prefix = literal },
    .k_or = .{},
    .k_print = .{},
    .k_return = .{},
    .k_super = .{},
    .k_this = .{},
    .k_true = .{ .prefix = literal },
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

    //expression();

    //consume(TokenType.k_eof, "Expect end of expression.");

    while (!match(.k_eof)) {
        declaration() catch |err| {
            errorAtPrevious(@errorName(err));
        };
    }

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

fn check(kind: TokenType) bool {
    return parser.current.kind == kind;
}

fn match(kind: TokenType) bool {
    if (!check(kind)) {
        return false;
    }

    advance();

    return true;
}

fn emitByte(byte: u8) !void {
    try currentChunk().writeChunk(byte, parser.previous.line);
}

fn emitBytes(a: u8, b: u8) !void {
    try emitByte(a);
    try emitByte(b);
}

fn emitByteArray(bytes: []const u8) !void {
    for (bytes) |byte| {
        try emitByte(byte);
    }
}

fn emitReturn() !void {
    try emitByte(OpCode.op_return.asByte());
}

fn makeConstant(value: Value) !chunk_mod.ConstantIndex {
    return try currentChunk().addConstant(value);
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

fn binary(_: bool) !void {
    const operator_type = parser.previous.kind;
    const rule = getRule(operator_type);
    parsePrecedence(@enumFromInt(@intFromEnum(rule.precedence) + 1));

    switch (operator_type) {
        TokenType.bang_equal => try emitBytes(OpCode.op_equal.asByte(), OpCode.op_not.asByte()),
        TokenType.equal_equal => try emitByte(OpCode.op_equal.asByte()),
        TokenType.greater => try emitByte(OpCode.op_greater.asByte()),
        TokenType.greater_equal => try emitBytes(OpCode.op_less.asByte(), OpCode.op_not.asByte()),
        TokenType.less => try emitByte(OpCode.op_less.asByte()),
        TokenType.less_equal => try emitBytes(OpCode.op_greater.asByte(), OpCode.op_not.asByte()),
        TokenType.plus => try emitByte(OpCode.op_add.asByte()),
        TokenType.minus => try emitByte(OpCode.op_subtract.asByte()),
        TokenType.star => try emitByte(OpCode.op_multiply.asByte()),
        TokenType.slash => try emitByte(OpCode.op_divide.asByte()),
        else => unreachable,
    }
}

fn literal(_: bool) !void {
    switch (parser.previous.kind) {
        TokenType.k_false => try emitByte(OpCode.op_false.asByte()),
        TokenType.k_nil => try emitByte(OpCode.op_nil.asByte()),
        TokenType.k_true => try emitByte(OpCode.op_true.asByte()),
        else => unreachable,
    }
}

fn grouping(_: bool) !void {
    expression();
    consume(TokenType.right_paren, "Expect ')' after expression.");
}

fn number(_: bool) !void {
    const double = try std.fmt.parseFloat(f64, parser.previous.data);

    try emitConstant(Value.fromNumber(double));
}

fn string(_: bool) !void {
    const object = try vm.manager().copy(parser.previous.data[1 .. parser.previous.data.len - 1]);
    try emitConstant(Value.fromObject(object));
}

fn namedVariable(name: *Token, can_assign: bool) !void {
    const index = try identifierConstant(name);

    if (can_assign and match(.equal)) {
        expression();
        switch (index) {
            .short => |i| {
                try emitBytes(OpCode.op_set_global.asByte(), i);
            },
            .long => |i| {
                const byte_low: u8 = @intCast(i & 0xF);
                const byte_middle: u8 = @intCast((i & 0xF0) >> 4);
                const byte_high: u8 = @intCast((i & 0xF00) >> 8);

                try emitByteArray(&[_]u8{ OpCode.op_set_global_long.asByte(), byte_high, byte_middle, byte_low });
            },
            else => {
                return error.ConstantIndexOverflow;
            },
        }
    } else {
        switch (index) {
            .short => |i| {
                try emitBytes(OpCode.op_get_global.asByte(), i);
            },
            .long => |i| {
                const byte_low: u8 = @intCast(i & 0xF);
                const byte_middle: u8 = @intCast((i & 0xF0) >> 4);
                const byte_high: u8 = @intCast((i & 0xF00) >> 8);

                try emitByteArray(&[_]u8{ OpCode.op_get_global_long.asByte(), byte_high, byte_middle, byte_low });
            },
            else => {
                return error.ConstantIndexOverflow;
            },
        }
    }
}
fn variable(can_assign: bool) !void {
    try namedVariable(&parser.previous, can_assign);
}

fn unary(_: bool) !void {
    const token_kind = parser.previous.kind;

    parsePrecedence(Precedence.unary);

    switch (token_kind) {
        TokenType.minus => try emitByte(OpCode.op_negate.asByte()),
        TokenType.bang => try emitByte(OpCode.op_not.asByte()),
        else => unreachable,
    }
}

fn parsePrecedence(precedence: Precedence) void {
    advance();
    // std.debug.print("Parsing Precedence: {s}\n", .{@tagName(parser.previous.kind)});

    const precedence_value = @intFromEnum(precedence);
    const can_assign = precedence_value <= @intFromEnum(Precedence.assignment);

    const prefix_option = getRule(parser.previous.kind).prefix;
    if (prefix_option) |prefix| {
        prefix(can_assign) catch |err| {
            errorAtPrevious(@errorName(err));
            return;
        };
    } else {
        errorAtPrevious("Expect expression.");
        return;
    }

    while (precedence_value <= @intFromEnum(getRule(parser.current.kind).precedence)) {
        advance();
        const infix_option = getRule(parser.previous.kind).infix;
        if (infix_option) |infix| {
            infix(can_assign) catch |err| {
                errorAtPrevious(@errorName(err));
            };
        }
    }

    if (can_assign and match(.equal)) {
        errorAtPrevious("Invalid assignment target.");
    }
}

fn identifierConstant(name: *Token) !ConstantIndex {
    const object = try vm.manager().copy(name.data);
    return makeConstant(Value.fromObject(object));
}

fn parseVariable(error_message: []const u8) !ConstantIndex {
    consume(.identifier, error_message);
    return try identifierConstant(&parser.previous);
}

fn defineVariable(index: ConstantIndex) !void {
    switch (index) {
        .short => |i| {
            try emitBytes(OpCode.op_define_global.asByte(), i);
        },
        .long => |i| {
            const byte_low: u8 = @intCast(i & 0xF);
            const byte_middle: u8 = @intCast((i & 0xF0) >> 4);
            const byte_high: u8 = @intCast((i & 0xF00) >> 8);

            try emitByteArray(&[_]u8{ OpCode.op_define_global_long.asByte(), byte_high, byte_middle, byte_low });
        },
        else => {
            return error.ConstantIndexOverflow;
        },
    }
}
fn getRule(kind: TokenType) *const ParseRule {
    return &rules[@as(usize, @intFromEnum(kind))];
}

fn expression() void {
    parsePrecedence(Precedence.assignment);
}

fn varDeclaration() !void {
    // We need to get bytes that point towards a constant
    const global = try parseVariable("Expect variable name.");

    if (match(.equal)) {
        expression();
    } else {
        try emitByte(OpCode.op_nil.asByte());
    }

    consume(.semicolon, "Expect ';' after variable declaration.");
    try defineVariable(global);
}

fn printStatement() !void {
    expression();
    consume(.semicolon, "Expect ';' after value.");
    try emitByte(OpCode.op_print.asByte());
}

fn expressionStatement() !void {
    expression();
    consume(.semicolon, "Expect ';' after value.");
    try emitByte(OpCode.op_pop.asByte());
}

fn synchronize() void {
    parser.panic_mode = false;

    while (parser.current.kind != .k_eof) : (advance()) {
        if (parser.previous.kind == .semicolon) {
            return;
        }

        switch (parser.current.kind) {
            .k_class, .k_fun, .k_var, .k_for, .k_if, .k_while, .k_print, .k_return => return,
            else => {},
        }
    }
}

fn declaration() !void {
    if (match(.k_var)) {
        try varDeclaration();
    } else {
        try statement();
    }

    if (parser.panic_mode) synchronize();
}

fn statement() !void {
    if (match(.k_print)) {
        try printStatement();
    } else {
        try expressionStatement();
    }
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
