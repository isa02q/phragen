const std = @import("std");

const wordlist_file = @embedFile("./wordlist");

pub const entry_count = 7776;
pub const max_word_length = 9;

pub const dictionary: [entry_count][]const u8 = blk: {
    @setEvalBranchQuota(entry_count * 50);

    var tokens: [entry_count][]const u8 = undefined;
    var it = std.mem.tokenizeAny(u8, wordlist_file, "\r\n");
    var i: usize = 0;
    while (it.next()) |token| : (i += 1) {
        tokens[i] = token;
    }

    break :blk tokens;
};

const assert = std.debug.assert;

comptime {
    assert(dictionary.len == entry_count);

    @setEvalBranchQuota(8000);
    const max_length = blk: {
        var max: usize = 0;
        for (dictionary) |entry| {
            if (entry.len > max) max = entry.len;
        }
        break :blk max;
    };
    assert(max_length == max_word_length);
}
