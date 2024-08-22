const std = @import("std");
const profiler = @import("../profiler/profiler.zig");

pub const TokenType = enum(u16) {
    none            = 0,
    left_brace      = 1 << 0,
    right_brace     = 1 << 1,
    left_bracket    = 1 << 2,
    right_bracket   = 1 << 3,
    colon           = 1 << 4,
    comma           = 1 << 5,
    eof             = 1 << 6,
    illegal         = 1 << 8,
    string          = 1 << 9,
    plus            = 1 << 10,
    minus           = 1 << 11,
    number          = 1 << 12,
    true            = 1 << 13,
    false           = 1 << 14,
};

pub const Token = struct {
    type: TokenType,
    string: []const u8,
};

pub const Lexer = struct {
    source: []u8,
    curr_pos: u32,
    next_pos: u32,
    char: u8,

    pub fn init(source: []u8) Lexer {
        return Lexer{
            .source = source,
            .curr_pos = 0,
            .next_pos = 1,
            .char = source[0]
        };
    }

    pub fn readChar(self: *Lexer) void {
        if (self.next_pos >= self.source.len) {
            self.char = 0;
        } else {
            self.char = self.source[self.next_pos];
        }

        self.curr_pos = self.next_pos;
        self.next_pos += 1;
    }

    pub fn skipWhitespace(self: *Lexer) void {
        while (self.char == '\n' or self.char == '\t' or self.char == ' ' or self.char == '\r') {
            self.readChar();
        }
    }


    pub inline fn peekChar(self: *Lexer) u8 {
        return if (self.next_pos < self.source.len) self.source[self.next_pos] else 0;
    }

    pub fn isPeekChar(self: *Lexer, exp_char: u8) bool {
        if (self.next_pos < self.source.len) {
            return self.source[self.next_pos] == exp_char;
        }

        return 0;
    }

    pub fn readString(self: *Lexer) []const u8 {
        
        const position = self.curr_pos;

        while (self.char != '"') {
           self.readChar();
        }

        return self.source[position..self.curr_pos];
    }

    pub fn readNumber(self: *Lexer) []const u8 {
        
        const position = self.curr_pos;

        while (isDigitOrSign(self.char) or self.char == '.') {
           self.readChar();
        }

        return self.source[position..self.curr_pos];
    }

    pub fn nextToken(self: *Lexer) Token {

        var token: Token = .{.type = .none, .string = ""};

        self.skipWhitespace();

        switch (self.char) {
            '{' => token = Token{.type = .left_brace, .string = "{"},
            '}' => token = Token{.type = .right_brace, .string = "}"},
            ':' => token = Token{.type = .colon, .string = ":"},
            ',' => token = Token{.type = .comma, .string = ","},
            '"' => {
                self.readChar();
                token = Token{.type = .string, .string = self.readString()};
            },
            '[' => token = Token{.type = .left_bracket, .string = "["},
            ']' => token = Token{.type = .right_bracket, .string = "]"},
            0 => token = Token{.type = .eof, .string = std.mem.zeroes([]const u8) },
            else => {
                if (isDigitOrSign(self.char)) {
                    const str = self.readNumber();

                    return .{.type = .number, .string = str};
                } else {
                    return .{.type = .illegal, .string = self.source[self.curr_pos..self.next_pos]};
                }
            }
        }

        self.readChar();

        return token;
    }

};

pub fn isLetter(char: u8) bool {
    const ascii_char = char - 32;

    return ascii_char >= 'A' and ascii_char <= 'Z';
}

pub inline fn isDigitOrSign(char: u8) bool {
    return (char >= '0' and char <= '9') or char == '-';
}
