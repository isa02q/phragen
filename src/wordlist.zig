const std = @import("std");

const wordlist_file = @embedFile("./wordlist");
const wordlist_entry_count = 7776;
pub const wordlist: [wordlist_entry_count][]const u8 = blk: {
    @setEvalBranchQuota(wordlist_entry_count * 50);

    var tokens: [wordlist_entry_count][]const u8 = undefined;
    var it = std.mem.tokenizeAny(u8, wordlist_file, "\r\n");
    var i = 0;
    while (it.next()) |token| : (i += 1) {
        tokens[i] = token;
    }

    break :blk tokens;
};
