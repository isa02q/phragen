const std = @import("std");
const words = @import("words.zig").words;

pub fn main(init: std.process.Init) !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();
    const allocator = debug_allocator.allocator();

    const rng_impl: std.Random.IoSource = .{ .io = init.io };
    const rng = rng_impl.interface();

    const passphrase = try generatePassphrase(allocator, rng, .{});
    defer allocator.free(passphrase);

    const buffer = try allocator.alloc(u8, passphrase.len + 1);
    defer allocator.free(buffer);
    var stdout_writer = std.Io.File.stdout().writer(init.io, buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("{s}\n", .{passphrase});
    try stdout.flush();
}

fn generatePassphrase(allocator: std.mem.Allocator, rng: std.Random, opt: GenerationOptions) ![]u8 {
    try opt.validate();

    var list: std.ArrayList(u8) = .empty;
    errdefer list.deinit(allocator);

    // Pick the first word before the loop to avoid the per-iteration separator necessity check.
    const firstword_index = rng.uintLessThan(usize, words.len);
    try list.appendSlice(allocator, words[firstword_index]);

    for (1..opt.word_count) |_| {
        try list.appendSlice(allocator, opt.separator);
        const index = rng.uintLessThan(usize, words.len);
        try list.appendSlice(allocator, words[index]);
    }

    return list.toOwnedSlice(allocator);
}

const min_word_count = 4;
const GenerationOptions = struct {
    word_count: usize = 6,
    separator: []const u8 = ",",

    fn validate(self: GenerationOptions) Error!void {
        if (self.word_count < min_word_count) {
            return Error.WordCountBelowMinimal;
        }
        for (self.separator) |char| {
            if (!isAllowedSeparatorSymbol(char)) {
                return Error.SeparatorContainsDisallowedCharacter;
            }
        }
    }

    const Error = error{ WordCountBelowMinimal, SeparatorContainsDisallowedCharacter };
};

fn isAllowedSeparatorSymbol(c: u8) bool {
    return switch (c) {
        '0'...'9', 'A'...'Z', 'a'...'z', '-', '=', '_', '.', ',', ' ', '/', ':', ';', '+', '~', '*', '#', '!', '?', '@' => true,
        else => false,
    };
}

test "generatePassphrase(): Generated passphrase respects both `word_count` and `separator` options" {
    const allocator = std.testing.allocator;

    var prng = std.Random.DefaultPrng.init(0);
    const random = prng.random();

    const word_count = 12;
    const separator = " ";
    const result = try generatePassphrase(std.testing.allocator, random, .{ .word_count = word_count, .separator = separator });
    defer allocator.free(result);

    var it = std.mem.splitSequence(u8, result, separator);
    var count: usize = 0;
    while (it.next()) |_| count += 1;
    try std.testing.expectEqual(@as(usize, word_count), count);
}

test "generatepassphrase(): PRNG initialized with a different seed generates a different passphrase" {
    const allocator = std.testing.allocator;

    var prng_foo = std.Random.DefaultPrng.init(0);
    const random_foo = prng_foo.random();
    var prng_bar = std.Random.DefaultPrng.init(1);
    const random_bar = prng_bar.random();

    const result_foo = try generatePassphrase(allocator, random_foo, .{});
    defer allocator.free(result_foo);
    const result_bar = try generatePassphrase(allocator, random_bar, .{});
    defer allocator.free(result_bar);

    try std.testing.expect(!std.mem.eql(u8, result_foo, result_bar));
}

test "generatePassphrase(): Error occurs if `word_count` is less than 4" {
    var prng = std.Random.DefaultPrng.init(0);
    const random = prng.random();

    const result = generatePassphrase(std.testing.allocator, random, .{ .word_count = 3 });

    try std.testing.expectError(GenerationOptions.Error.WordCountBelowMinimal, result);
}

test "generatePassphrase(): Error occurs if `separator` contains disallowed character" {
    var prng = std.Random.DefaultPrng.init(0);
    const random = prng.random();

    const result = generatePassphrase(std.testing.allocator, random, .{ .separator = "\t" });

    try std.testing.expectError(GenerationOptions.Error.SeparatorContainsDisallowedCharacter, result);
}
