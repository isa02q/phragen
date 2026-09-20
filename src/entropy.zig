const std = @import("std");

const passphrase = @import("passphrase.zig");

pub fn calculateEntropy(opt: passphrase.GenerationOptions, wordlist_entry_count: usize) f64 {
    const word_count: f64 = @floatFromInt(opt.word_count);
    const pool_size: f64 = @floatFromInt(wordlist_entry_count);

    var entropy = word_count * @log2(pool_size);

    const gap_count: f64 = @floatFromInt(opt.word_count - 1);

    entropy += switch (opt.separator) {
        .fixed, .none => 0,
        .digit => gap_count * @log2(@as(f64, passphrase.Separator.digit_pool.len)),
        .symbol => gap_count * @log2(@as(f64, passphrase.Separator.symbol_pool.len)),
        .mix => gap_count * @log2(@as(f64, passphrase.Separator.mixed_pool.len)),
    };

    return entropy;
}

test "calculateEntropy()" {
    const cases = [_]struct {
        opt: passphrase.GenerationOptions,
        expectedEntropy: f64,
    }{
        .{ .opt = .{}, .expectedEntropy = 77.55 },
        .{ .opt = .{ .word_count = 12, .separator = .digit }, .expectedEntropy = 191.6389 },
        .{ .opt = .{ .word_count = 8, .separator = .mix }, .expectedEntropy = 137.40 },
    };

    for (cases) |case| {
        const result = calculateEntropy(case.opt, 7776);
        try std.testing.expectApproxEqAbs(@as(f64, case.expectedEntropy), result, 0.01);
    }
}
