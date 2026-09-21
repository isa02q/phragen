const std = @import("std");

const wordlist = @import("wordlist.zig").wordlist;

const Allocator = std.mem.Allocator;
const Random = std.Random;

pub fn generatePassphrase(
    allocator: Allocator,
    rng: Random,
    opt: GenerationOptions,
) Allocator.Error![]u8 {
    var list: std.ArrayList(u8) = .empty;
    errdefer list.deinit(allocator);

    // Pick the first word before the loop to avoid the per-iteration separator necessity check.
    const firstword_index = rng.uintLessThan(usize, wordlist.len);
    try list.appendSlice(allocator, wordlist[firstword_index]);

    for (1..opt.word_count) |_| {
        if (opt.separator.resolve(rng)) |separator| {
            try list.append(allocator, separator);
        }
        const index = rng.uintLessThan(usize, wordlist.len);
        try list.appendSlice(allocator, wordlist[index]);
    }

    return list.toOwnedSlice(allocator);
}

pub const GenerationOptions = struct {
    passphrase_count: usize = 1,
    word_count: usize = 6,
    separator: Separator = .{ .fixed = ',' },

    pub fn validate(self: @This()) Error!void {
        if (self.passphrase_count < 1) {
            return Error.PassphraseCountBelowMinimum;
        }
        if (self.word_count < min_word_count) {
            return Error.WordCountBelowMinimum;
        }
        switch (self.separator) {
            .fixed => |char| {
                if (!Separator.isAllowedCharacter(char)) return Error.SeparatorIsDisallowedCharacter;
            },
            else => {},
        }
    }

    const Error = error{
        PassphraseCountBelowMinimum,
        WordCountBelowMinimum,
        SeparatorIsDisallowedCharacter,
    };

    const min_word_count = 4;
};

pub const Separator = union(enum) {
    fixed: u8,
    digit,
    symbol,
    mix,
    none, // disable separators

    pub const digit_pool = "0123456789";
    pub const symbol_pool = "-=_., /:;+~*#!?@$%&";
    pub const mixed_pool = digit_pool ++ symbol_pool;

    fn resolve(self: @This(), rng: Random) ?u8 {
        return switch (self) {
            .fixed => |c| c,
            .digit => digit_pool[rng.uintLessThan(usize, digit_pool.len)],
            .symbol => symbol_pool[rng.uintLessThan(usize, symbol_pool.len)],
            .mix => mixed_pool[rng.uintLessThan(usize, mixed_pool.len)],
            .none => null,
        };
    }

    fn isAllowedCharacter(char: u8) bool {
        return std.mem.indexOfScalar(u8, mixed_pool, char) != null;
    }

    // A map that converts reserved word strings passed via CLI into their corresponding enum values.
    pub const keywords = std.StaticStringMap(Separator).initComptime(.{
        .{ "digit", .digit },
        .{ "symbol", .symbol },
        .{ "mix", .mix },
        .{ "none", .none },
    });
};

test "generatePassphrase(): generated passphrase respects options" {
    var prng = std.Random.DefaultPrng.init(0);
    const random = prng.random();

    const opt: GenerationOptions = .{
        .word_count = 4, // threshold
        .separator = .{ .fixed = ' ' },
    };

    const allocator = std.testing.allocator;

    const passphrase = try generatePassphrase(allocator, random, opt);
    defer allocator.free(passphrase);

    var it = std.mem.splitScalar(u8, passphrase, opt.separator.fixed);
    var count: usize = 0;
    while (it.next()) |_| count += 1;
    try std.testing.expectEqual(@as(usize, opt.word_count), count);
}

test "opt.validate(): fails with expected error when invalid options passed" {
    const cases = [_]struct {
        opt: GenerationOptions,
        expectedError: GenerationOptions.Error,
    }{
        .{ .opt = .{ .passphrase_count = 0 }, .expectedError = GenerationOptions.Error.PassphraseCountBelowMinimum },
        .{ .opt = .{ .word_count = 3 }, .expectedError = GenerationOptions.Error.WordCountBelowMinimum },
        .{ .opt = .{ .word_count = 0 }, .expectedError = GenerationOptions.Error.WordCountBelowMinimum },
        .{ .opt = .{ .separator = .{ .fixed = '\\' } }, .expectedError = GenerationOptions.Error.SeparatorIsDisallowedCharacter },
        .{ .opt = .{ .separator = .{ .fixed = '`' } }, .expectedError = GenerationOptions.Error.SeparatorIsDisallowedCharacter },
    };

    for (cases) |case| {
        const result = case.opt.validate();
        try std.testing.expectError(case.expectedError, result);
    }
}
