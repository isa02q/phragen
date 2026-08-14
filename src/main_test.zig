const std = @import("std");
const phragen = @import("main.zig");

const ParseArgsError = phragen.ParseArgsError;
const GenerationOptions = phragen.GenerationOptions;
const GeneratePassphraseError = phragen.GeneratePassphraseError;

const Args = std.process.Args;
const Prng = std.Random.DefaultPrng;

const allocator = std.testing.allocator;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

test "parseArgs(): valid args are parsed correctly" {
    const cases = [_]struct {
        cmd: []const [*:0]const u8,
        expected: GenerationOptions,
    }{
        .{ .cmd = &.{ "phragen", "-c", "5" }, .expected = .{ .passphrase_count = 5 } },
        .{ .cmd = &.{ "phragen", "--count", "10" }, .expected = .{ .passphrase_count = 5 } },
        .{ .cmd = &.{ "phragen", "--words", "20" }, .expected = .{ .word_count = 20 } },
        .{ .cmd = &.{ "phragen", "-w", "4" }, .expected = .{ .word_count = 4 } },
        .{ .cmd = &.{ "phragen", "--separator", "-" }, .expected = .{ .separator = '-' } },
        .{ .cmd = &.{ "phragen", "-s", "!" }, .expected = .{ .separator = '!' } },
        .{ .cmd = &.{ "phragen", "-w", "12", "--separator", "^" }, .expected = .{ .word_count = 12, .separator = '^' } },
        .{ .cmd = &.{ "phragen", "-s", "%", "-w", "8" }, .expected = .{ .word_count = 8, .separator = '%' } },
    };

    for (cases) |case| {
        const args: Args = .{ .vector = case.cmd };
        const opt = try phragen.parseArgs(args, allocator);

        try expectEqual(case.expected.word_count, opt.word_count);
        try expectEqual(case.expected.separator, opt.separator);
    }
}

test "parseArgs(): fails with expected error when invalid args passed" {
    const cases = [_]struct {
        cmd: []const [*:0]const u8,
        expectedError: ParseArgsError,
    }{
        .{ .cmd = &.{ "phragen", "--count", "!" }, .expectedError = ParseArgsError.InvalidValue },
        .{ .cmd = &.{ "phragen", "--separator" }, .expectedError = ParseArgsError.MissingValue },
        .{ .cmd = &.{ "phragen", "-w" }, .expectedError = ParseArgsError.MissingValue },
        .{ .cmd = &.{ "phragen", "-w", "!" }, .expectedError = ParseArgsError.InvalidValue },
        .{ .cmd = &.{ "phragen", "-s", "??" }, .expectedError = ParseArgsError.InvalidValue },
        .{ .cmd = &.{ "phragen", "--word", "5" }, .expectedError = ParseArgsError.InvalidOption },
        .{ .cmd = &.{ "phragen", "--happy" }, .expectedError = ParseArgsError.InvalidOption },
        .{ .cmd = &.{ "phragen", "hello" }, .expectedError = ParseArgsError.UnexpectedArgument },
    };

    for (cases) |case| {
        const args: Args = .{ .vector = case.cmd };
        const result = phragen.parseArgs(args, allocator);

        try expectError(case.expectedError, result);
    }
}

test "generatePassphrase(): generated passphrase respects options" {
    var prng = Prng.init(0);
    const random = prng.random();

    const opt: GenerationOptions = .{
        .passphrase_count = 5,
        .word_count = 4, // threshold
        .separator = ' ',
    };

    const passphrases = try phragen.generatePassphrases(allocator, random, opt);
    defer {
        for (passphrases) |passphrase| allocator.free(passphrase);
        allocator.free(passphrases);
    }

    try expectEqual(passphrases.len, opt.passphrase_count);

    for (passphrases) |passphrase| {
        var it = std.mem.splitScalar(u8, passphrase, opt.separator);
        var count: usize = 0;
        while (it.next()) |_| count += 1;
        try expectEqual(@as(usize, opt.word_count), count);
    }
}

test "opt.validate(): fails with expected error when invalid options passed" {
    const cases = [_]struct {
        opt: GenerationOptions,
        expectedError: GenerationOptions.Error,
    }{
        .{ .opt = .{ .passphrase_count = 0 }, .expectedError = GenerationOptions.Error.PassphraseCountBelowMinimal },
        .{ .opt = .{ .word_count = 3 }, .expectedError = GenerationOptions.Error.WordCountBelowMinimal },
        .{ .opt = .{ .word_count = 0 }, .expectedError = GenerationOptions.Error.WordCountBelowMinimal },
        .{ .opt = .{ .separator = '\\' }, .expectedError = GenerationOptions.Error.SeparatorIsDisallowedCharacter },
        .{ .opt = .{ .separator = '`' }, .expectedError = GenerationOptions.Error.SeparatorIsDisallowedCharacter },
    };

    for (cases) |case| {
        const result = case.opt.validate();
        try expectError(case.expectedError, result);
    }
}
