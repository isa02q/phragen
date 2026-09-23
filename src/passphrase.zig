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
    word_count: usize = 6,
    separator: Separator = .{ .fixed = '.' },

    pub fn validate(self: @This()) Error!void {
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
    none, // Disable separators.

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

fn testPassphraseWordCount(word_count: usize) !void {
    var prng = Random.DefaultPrng.init(0);
    const random = prng.random();

    const allocator = std.testing.allocator;

    const passphrase = try generatePassphrase(allocator, random, .{ .word_count = word_count });
    defer allocator.free(passphrase);

    var it = std.mem.splitScalar(u8, passphrase, '.');
    var count: usize = 0;
    while (it.next()) |_| count += 1;

    try std.testing.expectEqual(word_count, count);
}

test "The word count matches across various sizes" {
    try testPassphraseWordCount(4);
    try testPassphraseWordCount(12);
    try testPassphraseWordCount(50);
    try testPassphraseWordCount(1000);
}

fn testGeneratePassphrase(opt: GenerationOptions) !void {
    var prng = std.Random.DefaultPrng.init(0);
    const random = prng.random();

    const allocator = std.testing.allocator;
    const expect = std.testing.expect;
    const isAlphabetic = std.ascii.isAlphabetic;

    const passphrase = try generatePassphrase(allocator, random, opt);
    defer allocator.free(passphrase);

    try expect(isAlphabetic(passphrase[0]));
    try expect(isAlphabetic(passphrase[passphrase.len - 1]));

    switch (opt.separator) {
        .fixed => unreachable,
        .digit => {
            for (passphrase) |char| try expect(std.ascii.isAlphanumeric(char));
        },
        .symbol => {
            for (passphrase) |char| {
                const isAllowed = blk: {
                    if (std.mem.indexOfScalar(u8, Separator.symbol_pool, char) != null) break :blk true;
                    break :blk isAlphabetic(char);
                };
                try expect(isAllowed);
            }
        },
        .mix => {
            for (passphrase) |char| {
                const isAllowed = blk: {
                    if (std.mem.indexOfScalar(u8, Separator.mixed_pool, char) != null) break :blk true;
                    break :blk isAlphabetic(char);
                };
                try expect(isAllowed);
            }
        },
        .none => {
            for (passphrase) |char| try expect(isAlphabetic(char));
        },
    }
}

test "generatePassphrase() respects given options" {
    try testGeneratePassphrase(.{ .separator = .digit });
    try testGeneratePassphrase(.{ .separator = .symbol });
    try testGeneratePassphrase(.{ .separator = .mix });
    try testGeneratePassphrase(.{ .separator = .none });
}

fn testOptionsValidate(
    opt: GenerationOptions,
    expected: GenerationOptions.Error,
) !void {
    const result = opt.validate();
    try std.testing.expectError(expected, result);
}

test "Invalid options return an expected error" {
    try testOptionsValidate(.{ .word_count = 3 }, GenerationOptions.Error.WordCountBelowMinimum);
    try testOptionsValidate(.{ .word_count = 0 }, GenerationOptions.Error.WordCountBelowMinimum);
    try testOptionsValidate(.{ .separator = .{ .fixed = '\\' } }, GenerationOptions.Error.SeparatorIsDisallowedCharacter);
    try testOptionsValidate(.{ .separator = .{ .fixed = '`' } }, GenerationOptions.Error.SeparatorIsDisallowedCharacter);
}

pub const Preset = union(enum) {
    master,
    simple,
    pin,
    extreme,

    pub fn options(self: @This()) GenerationOptions {
        return switch (self) {
            .master => .{
                .word_count = 8,
                .separator = .mix,
            },
            .simple => .{
                .word_count = 6,
                .separator = .{ .fixed = '-' },
            },
            .pin => .{
                .word_count = 4,
                .separator = .digit,
            },
            .extreme => .{
                .word_count = 14,
                .separator = .mix,
            },
        };
    }

    pub const keywords = std.StaticStringMap(Preset).initComptime(.{
        .{ "master", .master },
        .{ "simple", .simple },
        .{ "pin", .pin },
        .{ "extreme", .extreme },
    });
};

fn testPreset(preset: Preset, expected: GenerationOptions) !void {
    const opt = preset.options();
    try opt.validate(); // Check whether the options provided by the preset are valid.

    try std.testing.expectEqual(expected, opt);
}

test "Preset.options()" {
    try testPreset(.master, .{ .word_count = 8, .separator = .mix });
    try testPreset(.simple, .{ .word_count = 6, .separator = .{ .fixed = '-' } });
    try testPreset(.pin, .{ .word_count = 4, .separator = .digit });
    try testPreset(.extreme, .{ .word_count = 14, .separator = .mix });
}
