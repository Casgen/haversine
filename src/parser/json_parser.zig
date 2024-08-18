const haversine = @import("../haversine/haversine.zig");
const std = @import("std");

pub const TokenType = enum(u16) {
    none            = 0,
    left_brace      = 1 << 0,
    right_brace     = 1 << 1,
    left_bracket    = 1 << 2,
    right_bracket   = 1 << 3,
    colon           = 1 << 4,
    comma           = 1 << 5,
    eof             = 1 << 6,
    quotation_mark  = 1 << 7,
    illegal         = 1 << 8,
    string          = 1 << 9,
    plus            = 1 << 10,
    minus           = 1 << 11,
    number          = 1 << 12,
};

pub const Token = struct {
    type: TokenType,
    string: []const u8,
};

pub const ParseError = error {
    UnexpectedToken
};

const begin_tokens = [_]Token{
    .{.type = .left_brace, .string = "{"},
    .{.type = .quotation_mark, .string = "\""},
    .{.type = .string, .string = "pairs"},
    .{.type = .quotation_mark, .string = "\""},
    .{.type = .colon, .string = ":"},
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

        while (isDigit(self.char) or self.char == '.') {
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
            '-' => token = Token{.type = .minus, .string = "-"},
            '+' => token = Token{.type = .plus, .string = "+"},
            '"' => token = Token{.type = .quotation_mark, .string = "\""},
            '[' => token = Token{.type = .left_bracket, .string = "["},
            ']' => token = Token{.type = .right_bracket, .string = "]"},
            0 => token = Token{.type = .eof, .string = std.mem.zeroes([]const u8) },
            else => {
                if (isLetter(self.char)) {
                    const str = self.readString();

                    return .{.type = .string, .string = str};
                } else if (isDigit(self.char)) {
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

pub const Parser = struct {
    lexer: Lexer,
    curr_token: Token,
    peek_token: Token,

    pub fn init(source: []u8) Parser {

        var parser = Parser{
            .lexer = Lexer.init(source),
            .curr_token = undefined,
            .peek_token = undefined,
        };

        parser.curr_token = parser.lexer.nextToken();
        parser.peek_token = parser.lexer.nextToken();

        return parser;
    }

    pub fn nextToken(self: *Parser) void {
        self.curr_token = self.peek_token;
        self.peek_token = self.lexer.nextToken();
    }

    pub fn parseObject(self: *Parser) ParseError!haversine.Coordinates {

        var obj: haversine.Coordinates = .{ .x0 = 0, .x1 = 0, .y0 = 0, .y1 = 0 };

        try expectType(self.curr_token.type, TokenType.left_brace);

        self.nextToken();

        while (true) {

            try expectType(self.curr_token.type, TokenType.quotation_mark);

            self.nextToken();
            try expectType(self.curr_token.type, TokenType.string);

            const field_str = self.curr_token.string;
            
            self.nextToken();
            try expectType(self.curr_token.type, TokenType.quotation_mark);

            self.nextToken();
            try expectType(self.curr_token.type, TokenType.colon);

            self.nextToken();

            var sign: f64 = 1;

            if (self.curr_token.type == TokenType.minus) {
                sign = -1;
                self.nextToken();
            }


            if (std.mem.eql(u8, field_str, "x0")) {
                obj.x0 = std.fmt.parseFloat(f64, self.curr_token.string) catch {
                    return ParseError.UnexpectedToken;
                };

                obj.x0 *= sign;
            }

            if (std.mem.eql(u8, field_str, "x1")) {
                obj.x1 = std.fmt.parseFloat(f64, self.curr_token.string) catch {
                    return ParseError.UnexpectedToken;
                };
                obj.x1 *= sign;
            }

            if (std.mem.eql(u8, field_str, "y0")) {
                obj.y0 = std.fmt.parseFloat(f64, self.curr_token.string) catch {
                    std.debug.print("Float: {d}\n\n",.{ self.curr_token.string });
                    return ParseError.UnexpectedToken;
                };
                obj.y0 *= sign;
            }

            if (std.mem.eql(u8, field_str, "y1")) {
                obj.y1 = std.fmt.parseFloat(f64, self.curr_token.string) catch {
                    return ParseError.UnexpectedToken;
                };
                obj.y1 *= sign;

            }

            self.nextToken();
            
            try expectTypeInt(@intFromEnum(self.curr_token.type), @intFromEnum(TokenType.comma) | @intFromEnum(TokenType.right_brace));

            if (self.curr_token.type == TokenType.right_brace) {
                self.nextToken();
                return obj;
            }

            self.nextToken();

        }

    }


    pub fn parseArray(self: *Parser, allocator: std.mem.Allocator) ParseError!std.ArrayList(haversine.Coordinates) {

        var coords = std.ArrayList(haversine.Coordinates).init(allocator);

        self.nextToken();

        while (true) {
            try expectType(self.curr_token.type, TokenType.left_brace);

            const obj = try self.parseObject();

            coords.append(obj) catch {
                _ = std.io.getStdErr().writer().write("Failed to append coordinates!") catch {
                    std.process.abort();
                };
                std.process.abort();
            };

            if (self.curr_token.type == TokenType.comma) {
                self.nextToken();
                continue;
            }

            try expectType(self.curr_token.type, TokenType.right_bracket);
            break;
        }

        return coords; 

    }

    pub fn parseCoordinates(self: *Parser, allocator: std.mem.Allocator) ParseError!std.ArrayList(haversine.Coordinates) {

        for (&begin_tokens) |*t|  {
            if (self.curr_token.type == t.type and std.mem.eql(u8, self.curr_token.string, t.string)) {
                self.nextToken();
                continue;
            }
            return ParseError.UnexpectedToken;
        }

        var coords: std.ArrayList(haversine.Coordinates) = undefined;

        while (self.curr_token.type != TokenType.eof) {

            switch (self.curr_token.type) {
                TokenType.left_bracket => coords = try parseArray(self, allocator),
                TokenType.right_brace => break,
                else => {
                    std.debug.print("Non-handled token type case! {}", .{self.curr_token.type});
                    unreachable;
                } 
            }

            self.nextToken();
        }

        return coords;
    }
};

pub fn parseHaversinePairs(allocator: std.mem.Allocator, source: []u8) ParseError!std.ArrayList(haversine.Coordinates) {
    var parser = Parser.init(source);

    return parser.parseCoordinates(allocator);
}


pub fn isLetter(char: u8) bool {
    const ascii_char = char - 32;

    return ascii_char >= 'A' and ascii_char <= 'Z';
}

pub inline fn isDigit(char: u8) bool {
    return char >= '0' and char <= '9';
}

pub fn expectType(token_type: TokenType, exp_type: TokenType) ParseError!void {
    if (token_type != exp_type) {
        std.debug.print("Failed to parse a token! Expected: {}, Actual: {}\n", .{exp_type, token_type});
        return ParseError.UnexpectedToken;
    }
}

pub fn expectTypeInt(token_type: u16, exp_type: u16) ParseError!void {
    if (token_type & exp_type == 0) {
        std.debug.print("Failed to parse a token! Expected: {d}, Actual: {d}\n", .{exp_type, token_type});
        return ParseError.UnexpectedToken;
    }
}
