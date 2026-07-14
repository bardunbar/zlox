pub const TokenType = enum {
    // Single Character Tokens
    left_paren,
    right_paren,
    left_brace,
    right_brace,
    comma,
    dot,
    minus,
    plus,
    semicolon,
    slash,
    star,

    // One or Two Character Tokens
    bang,
    bang_equal,
    equal,
    equal_equal,
    greater,
    greater_equal,
    less,
    less_equal,

    //Literals
    identifier,
    string,
    number,

    // Keywords
    k_and,
    k_class,
    k_else,
    k_false,
    k_for,
    k_fun,
    k_if,
    k_nil,
    k_or,
    k_print,
    k_return,
    k_super,
    k_this,
    k_true,
    k_var,
    k_while,

    k_error,
    k_eof,
};

pub const Token = struct {
    kind: TokenType,
    data: []const u8,
    line: u32,
};

const Scanner = struct {
    source: []const u8,
    start: [*]const u8,
    current: [*]const u8,
    line: u32,
};

var scanner: Scanner = undefined;

pub fn init(source: []const u8) void {
    scanner.source = source;
    scanner.start = source.ptr;
    scanner.current = source.ptr;
    scanner.line = 1;
}

pub fn nextToken() Token {
    skipWhitespace();

    scanner.start = scanner.current;

    if (isAtEnd()) {
        return makeToken(TokenType.k_eof);
    }

    const char = advance();

    if (isDigit(char)) {
        return number();
    }

    switch (char) {
        '(' => return makeToken(TokenType.left_paren),
        ')' => return makeToken(TokenType.right_paren),
        '{' => return makeToken(TokenType.left_brace),
        '}' => return makeToken(TokenType.right_brace),
        ';' => return makeToken(TokenType.semicolon),
        ',' => return makeToken(TokenType.comma),
        '.' => return makeToken(TokenType.dot),
        '-' => return makeToken(TokenType.minus),
        '+' => return makeToken(TokenType.plus),
        '/' => return makeToken(TokenType.slash),
        '*' => return makeToken(TokenType.star),
        '!' => return makeToken(if (match('=')) TokenType.bang_equal else TokenType.bang),
        '=' => return makeToken(if (match('=')) TokenType.equal_equal else TokenType.equal),
        '<' => return makeToken(if (match('=')) TokenType.less_equal else TokenType.less),
        '>' => return makeToken(if (match('=')) TokenType.greater_equal else TokenType.greater),
        '"' => return string(),
        else => {},
    }

    return errorToken("Unexpected character.");
}

fn advance() u8 {
    const current = scanner.current[0];
    scanner.current += 1;
    return current;
}

fn skipWhitespace() void {
    var c = peek();
    while (true) : (c = peek()) {
        switch (c) {
            ' ', '\r', '\t' => {
                _ = advance();
                break;
            },
            '\n' => {
                scanner.line += 1;
                _ = advance();
                break;
            },
            '/' => {
                if (peekNext() == '/') {
                    while (peek() != '\n' and !isAtEnd()) {
                        _ = advance();
                    }
                } else {
                    return;
                }
            },
            else => {
                return;
            }
        }
    }
}

fn peek() u8 {
    return scanner.current[0];
}

fn peekNext() u8 {
    if (isAtEnd()) {
        return 0;
    }

    return scanner.current[1];
}

fn match(expected: u8) bool {
    if (isAtEnd()) {
        return false;
    }

    if (scanner.current[0] != expected) {
        return false;
    }

    scanner.current += 1;
    return true;
}

fn isAtEnd() bool {
    return scanner.current == scanner.source.ptr + scanner.source.len;
}

fn isDigit(char: u8) bool {
    return char >= '0' and char <= '9';
}

fn string() Token {
    while (peek() != '"' and !isAtEnd()) : (_ = advance()) {
        if (peek() == '\n') {
            scanner.line += 1;
        }
    }

    if (isAtEnd()) {
        return errorToken("Unterminated string");
    }

    _ = advance();
    return makeToken(TokenType.string);
}

fn number() Token {
    while (isDigit(peek())) : (_ = advance()) {}

    if (peek() == '.' and isDigit(peekNext())) {
        _ = advance();

        while (isDigit(peek())) : (_ = advance()) {}
    }

    return makeToken(TokenType.number);
}

fn makeToken(kind: TokenType) Token {
    return .{
        .kind = kind,
        .data = scanner.start[0 .. scanner.current - scanner.start], //.{ .ptr = scanner.start, .len = scanner.current - scanner.start },
        .line = scanner.line,
    };
}

fn errorToken(message: []const u8) Token {
    return .{
        .kind = TokenType.k_error,
        .data = message,
        .line = scanner.line,
    };
}
