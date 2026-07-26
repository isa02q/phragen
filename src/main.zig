const std = @import("std");
const parg = @import("parg");

const words = @import("words.zig").words;

const Allocator = std.mem.Allocator;
const Args = std.process.Args;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.arena.allocator();

    const rng_impl: std.Random.IoSource = .{ .io = io };
    const rng = rng_impl.interface();

    const opt = try parseArgs(init.minimal.args, allocator);

    const passphrase = try generatePassphrase(allocator, rng, opt);

    const buffer = try allocator.alloc(u8, passphrase.len + 1);
    var stdout_writer = std.Io.File.stdout().writer(io, buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("{s}\n", .{passphrase});
    try stdout.flush();
}

pub fn parseArgs(args: Args, allocator: Allocator) ParseArgsError!GenerationOptions {
    const slice = try Args.toSlice(args, allocator);
    defer allocator.free(slice);

    var p = parg.parseSlice(slice, .{});
    defer p.deinit();

    // `std.process.Args` holds program name as the first entry.
    const program_name = p.next() orelse unreachable;
    _ = program_name;

    var opt = GenerationOptions{};

    while (p.next()) |token| {
        switch (token) {
            .flag => |flag| {
                if (flag.isLong("words") or flag.isShort("w")) {
                    const word_count_str = p.nextValue() orelse return ParseArgsError.MissingValue;
                    opt.word_count = std.fmt.parseInt(usize, word_count_str, 10) catch return ParseArgsError.InvalidValue;
                } else if (flag.isLong("separator") or flag.isShort("s")) {
                    opt.separator = p.nextValue() orelse return ParseArgsError.MissingValue;
                } else {
                    return ParseArgsError.InvalidOption;
                }
            },
            .arg => return ParseArgsError.UnexpectedArgument,
            .unexpected_value => return ParseArgsError.UnexpectedValue,
        }
    }

    return opt;
}

pub const ParseArgsError = error{ MissingValue, InvalidValue, InvalidOption, UnexpectedValue, UnexpectedArgument } || Args.ToSliceError;

pub fn generatePassphrase(allocator: Allocator, rng: std.Random, opt: GenerationOptions) GeneratePassphraseError![]u8 {
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

pub const GeneratePassphraseError = GenerationOptions.Error || Allocator.Error;

pub const GenerationOptions = struct {
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

const min_word_count = 4;
fn isAllowedSeparatorSymbol(c: u8) bool {
    return switch (c) {
        '0'...'9', 'A'...'Z', 'a'...'z', '-', '=', '_', '.', ',', ' ', '/', ':', ';', '+', '~', '*', '#', '!', '?', '@' => true,
        else => false,
    };
}
