const haversine = @import("../haversine/haversine.zig");
const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("lexer.zig").Token;
const TokenType = @import("lexer.zig").TokenType;
const profiler = @import("../profiler/profiler.zig");

pub const JsonType = enum {
    unrecognized,
    array,
    string,
    bool,
    number,
    object,
};


pub const ParseError = error {
    UnexpectedToken,
    AllocationFailed,
};

pub const JsonElement = struct {
    type: JsonType,
    label: []const u8 = "",
    value: []const u8 = "",
    elements: ?[]JsonElement,

    pub fn deinit(self: *JsonElement, allocator: std.mem.Allocator) void {

        if (self.elements == null) {
            return;
        }

        for (self.elements.?) |*el| {
            el.deinit(allocator);
        }

        allocator.free(self.elements.?);
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

    /// Advances to the next token and returns it.
    pub fn nextToken(self: *Parser) Token {
        self.curr_token = self.peek_token;
        self.peek_token = self.lexer.nextToken();

        return self.curr_token;
    }

    pub fn parseJson(self: *Parser, allocator: std.mem.Allocator) ParseError!JsonElement {

        var json_el: ParseError!JsonElement = undefined;

        while (self.curr_token.type != TokenType.eof) {

            switch (self.curr_token.type) {
                TokenType.left_brace => json_el = try self.parseJsonObject(allocator, ""),
                TokenType.left_bracket => json_el = try self.parseJsonArray(allocator, ""),
                else => {
                    std.debug.print("Failed to parse a token! Expected: \"{{\" or \"[\" , Actual: {s}\n", .{self.curr_token.string});
                    return ParseError.UnexpectedToken;
                }
            }

            _ = self.nextToken();
        }

        return json_el;
    }

    pub fn parseJsonArray(self: *Parser, allocator: std.mem.Allocator, label: []const u8) ParseError!JsonElement {
        const idx = struct { var curr: u64 = 0;};
        const block = profiler.beginBlock("Parse Array", &idx.curr);
        defer block.end();

        try expectType(self.curr_token.type, TokenType.left_bracket);

        var elements = std.ArrayList(JsonElement).init(allocator);

        _ = self.nextToken();

        while (true) {

            switch (self.curr_token.type) {
                TokenType.left_brace => {
                    const el = try self.parseJsonObject(allocator, "");

                    elements.append(el) catch {
                         return ParseError.AllocationFailed;
                    };
                },
                else => return ParseError.UnexpectedToken
            }

            _ = self.nextToken();

            if (self.curr_token.type == TokenType.comma) {
                _ = self.nextToken();
                continue;
            }

            if (self.curr_token.type == TokenType.right_bracket) {
                break;
            }

            std.debug.print("Failed to parse a token! Expected: ']' or ',', Actual: {s}\n", .{self.curr_token.string});
            return ParseError.UnexpectedToken;
        }

        const elements_slice = elements.toOwnedSlice() catch {
            return ParseError.AllocationFailed;
        };

        return JsonElement{
            .type = .array,
            .elements = elements_slice,
            .label = label,
            .value = ""
        };


    }

    pub fn parseJsonObject(self: *Parser, allocator: std.mem.Allocator, label: []const u8) ParseError!JsonElement {

        const idx = struct { var curr: u64 = 0;};
        const block = profiler.beginBlock("Parse Object", &idx.curr);
        defer block.end();

        try expectType(self.curr_token.type, TokenType.left_brace);

        var elements = std.ArrayList(JsonElement).init(allocator);

        _ = self.nextToken();

        while (true) {

            try expectType(self.curr_token.type, TokenType.string);

            const el_label = self.curr_token.string;

            try expectType(self.nextToken().type, TokenType.colon);

            _ = self.nextToken();

            switch (self.curr_token.type) {
                TokenType.left_bracket => {
                    const el = try parseJsonArray(self, allocator, el_label);
                    elements.append(el) catch {
                        return ParseError.AllocationFailed;
                    };
                }
                ,
                TokenType.number => {
                    elements.append(.{
                        .type = .number,
                        .value = self.curr_token.string,
                        .elements = null,
                        .label = el_label
                    }) catch {
                        return ParseError.AllocationFailed;
                    };
                },
                TokenType.string => {
                    elements.append(.{
                        .type = .string,
                        .value = self.curr_token.string,
                        .elements = null,
                        .label = el_label
                    }) catch {
                        return ParseError.AllocationFailed;
                    };
                },
                else => unreachable
            }

            _ = self.nextToken();

            if (self.curr_token.type == TokenType.comma) {
                _ = self.nextToken();
                continue;
            }

            if (self.curr_token.type == TokenType.right_brace) {
                break;
            }
            
            std.debug.print("Failed to parse a token! Expected: \",\" or \"}}\", Actual: {s}\n", .{self.curr_token.string});
            return ParseError.UnexpectedToken;
        }

        const elements_slice = elements.toOwnedSlice() catch {
            return ParseError.AllocationFailed;
        };

        return JsonElement{
            .type = .object,
            .value = "",
            .elements = elements_slice,
            .label = label
        };

    }
};


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
