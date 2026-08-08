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
const expectEqualStrings = std.testing.expectEqualStrings;

test "parseArgs(): valid args are parsed correctly" {
    const cases = [_]struct {
        cmd: []const [*:0]const u8,
        expected: GenerationOptions,
    }{
        .{ .cmd = &.{ "phragen", "--words", "20" }, .expected = .{ .word_count = 20 } },
        .{ .cmd = &.{ "phragen", "-w", "4" }, .expected = .{ .word_count = 4 } },
        .{ .cmd = &.{ "phragen", "--separator", "-" }, .expected = .{ .separator = "-" } },
        .{ .cmd = &.{ "phragen", "-s", "!" }, .expected = .{ .separator = "!" } },
        .{ .cmd = &.{ "phragen", "-w", "12", "--separator", "^" }, .expected = .{ .word_count = 12, .separator = "^" } },
        .{ .cmd = &.{ "phragen", "-s", "%", "-w", "8" }, .expected = .{ .word_count = 8, .separator = "%" } },
    };

    for (cases) |case| {
        const args: Args = .{ .vector = case.cmd };
        const opt = try phragen.parseArgs(args, allocator);

        try expectEqual(case.expected.word_count, opt.word_count);
        try expectEqualStrings(case.expected.separator, opt.separator);
    }
}

test "parseArgs(): fails with expected error when invalid args passed" {
    const cases = [_]struct {
        cmd: []const [*:0]const u8,
        expectedError: ParseArgsError,
    }{
        .{ .cmd = &.{ "phragen", "--separator" }, .expectedError = ParseArgsError.MissingValue },
        .{ .cmd = &.{ "phragen", "-w" }, .expectedError = ParseArgsError.MissingValue },
        .{ .cmd = &.{ "phragen", "-w", "!" }, .expectedError = ParseArgsError.InvalidValue },
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
        .word_count = 4, // threshold
        .separator = " ",
    };

    const result = try phragen.generatePassphrase(allocator, random, opt);
    defer allocator.free(result);

    var it = std.mem.splitSequence(u8, result, opt.separator);
    var count: usize = 0;
    while (it.next()) |_| count += 1;
    try expectEqual(@as(usize, opt.word_count), count);
}

test "generatePassphrase(): fails with expected error when invalid options passed" {
    const cases = [_]struct {
        opt: GenerationOptions,
        expectedError: GeneratePassphraseError,
    }{
        .{ .opt = .{ .word_count = 3 }, .expectedError = GeneratePassphraseError.WordCountBelowMinimal },
        .{ .opt = .{ .word_count = 0 }, .expectedError = GeneratePassphraseError.WordCountBelowMinimal },
        .{ .opt = .{ .separator = "\\" }, .expectedError = GeneratePassphraseError.SeparatorContainsDisallowedCharacter },
        .{ .opt = .{ .separator = "`" }, .expectedError = GeneratePassphraseError.SeparatorContainsDisallowedCharacter },
    };

    var prng = Prng.init(0);
    const random = prng.random();

    for (cases) |case| {
        const result = phragen.generatePassphrase(allocator, random, case.opt);
        try expectError(case.expectedError, result);
    }
}
