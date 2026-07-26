const std = @import("std");
const phragen = @import("main.zig");

const GenerationOptions = phragen.GenerationOptions;
const GeneratePassphraseError = phragen.GeneratePassphraseError;

const Prng = std.Random.DefaultPrng;

const allocator = std.testing.allocator;
const expectError = std.testing.expectError;

test "generatePassphrase(): Generated passphrase respects both `word_count` and `separator` options" {
    var prng = Prng.init(0);
    const random = prng.random();

    const opt: GenerationOptions = .{
        .word_count = 12,
        .separator = " ",
    };
    const result = try phragen.generatePassphrase(allocator, random, opt);
    defer allocator.free(result);

    var it = std.mem.splitSequence(u8, result, opt.separator);
    var count: usize = 0;
    while (it.next()) |_| count += 1;
    try std.testing.expectEqual(@as(usize, opt.word_count), count);
}

test "generatepassphrase(): PRNG initialized with a different seed generates a different passphrase" {
    var prng_foo = Prng.init(0);
    const random_foo = prng_foo.random();
    var prng_bar = Prng.init(1);
    const random_bar = prng_bar.random();

    const result_foo = try phragen.generatePassphrase(allocator, random_foo, .{});
    defer allocator.free(result_foo);
    const result_bar = try phragen.generatePassphrase(allocator, random_bar, .{});
    defer allocator.free(result_bar);

    try std.testing.expect(!std.mem.eql(u8, result_foo, result_bar));
}

test "generatePassphrase(): Error occurs if `word_count` is less than 4" {
    var prng = Prng.init(0);
    const random = prng.random();

    const result = phragen.generatePassphrase(allocator, random, .{ .word_count = 3 });

    try expectError(GeneratePassphraseError.WordCountBelowMinimal, result);
}

test "generatePassphrase(): Error occurs if `separator` contains disallowed character" {
    var prng = Prng.init(0);
    const random = prng.random();

    const result = phragen.generatePassphrase(allocator, random, .{ .separator = "\t" });

    try expectError(GeneratePassphraseError.SeparatorContainsDisallowedCharacter, result);
}
