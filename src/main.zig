const std = @import("std");
const parg = @import("parg");
const build_options = @import("build_options");

const words = @import("words.zig").words;

const Allocator = std.mem.Allocator;
const Args = std.process.Args;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.arena.allocator();
    const rng_impl: std.Random.IoSource = .{ .io = io };
    const rng = rng_impl.interface();

    for (init.minimal.args.vector[1..]) |arg| {
        const arg_str = std.mem.span(arg);
        if (std.mem.eql(u8, arg_str, "--version") or std.mem.eql(u8, arg_str, "-v")) {
            const version = std.fmt.comptimePrint("{f}\n", .{build_options.version});
            try std.Io.File.stdout().writeStreamingAll(io, version);
            std.process.exit(0);
        }
    }

    const opt = try parseArgs(init.minimal.args, allocator);
    try opt.validate();

    const passphrases = try generatePassphrases(allocator, rng, opt);

    const buffer = try allocator.alloc(u8, opt.word_count * 10 * opt.passphrase_count);
    var stdout_writer = std.Io.File.stdout().writer(io, buffer);
    const stdout = &stdout_writer.interface;
    for (passphrases) |passphrase| {
        try stdout.print("{s}\n", .{passphrase});
    }
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
                if (flag.isLong("count") or flag.isShort("c")) {
                    const passphrase_count_str = p.nextValue() orelse return ParseArgsError.MissingValue;
                    opt.passphrase_count = std.fmt.parseInt(usize, passphrase_count_str, 10) catch return ParseArgsError.InvalidValue;
                } else if (flag.isLong("words") or flag.isShort("w")) {
                    const word_count_str = p.nextValue() orelse return ParseArgsError.MissingValue;
                    opt.word_count = std.fmt.parseInt(usize, word_count_str, 10) catch return ParseArgsError.InvalidValue;
                } else if (flag.isLong("separator") or flag.isShort("s")) {
                    const separator_str = p.nextValue() orelse return ParseArgsError.MissingValue;
                    if (separator_str.len != 1) return ParseArgsError.InvalidValue;
                    opt.separator = separator_str[0];
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

pub const ParseArgsError = error{
    MissingValue,
    InvalidValue,
    InvalidOption,
    UnexpectedValue,
    UnexpectedArgument,
} || Args.ToSliceError;

pub fn generatePassphrases(
    allocator: Allocator,
    rng: std.Random,
    opt: GenerationOptions,
) Allocator.Error![][]u8 {
    var passphrases: std.ArrayList([]u8) = .empty;
    errdefer {
        for (passphrases.items) |item| allocator.free(item);
        passphrases.deinit(allocator);
    }

    for (0..opt.passphrase_count) |_| {
        const passphrase = try generateSinglePassphrase(allocator, rng, opt);
        try passphrases.append(allocator, passphrase);
    }

    return passphrases.toOwnedSlice(allocator);
}

fn generateSinglePassphrase(
    allocator: Allocator,
    rng: std.Random,
    opt: GenerationOptions,
) Allocator.Error![]u8 {
    var list: std.ArrayList(u8) = .empty;
    errdefer list.deinit(allocator);

    // Pick the first word before the loop to avoid the per-iteration separator necessity check.
    const firstword_index = rng.uintLessThan(usize, words.len);
    try list.appendSlice(allocator, words[firstword_index]);

    for (1..opt.word_count) |_| {
        try list.append(allocator, opt.separator);
        const index = rng.uintLessThan(usize, words.len);
        try list.appendSlice(allocator, words[index]);
    }

    return list.toOwnedSlice(allocator);
}

pub const GenerationOptions = struct {
    passphrase_count: usize = 1,
    word_count: usize = 6,
    separator: u8 = ',',

    pub fn validate(self: GenerationOptions) Error!void {
        if (self.passphrase_count < 1) {
            return Error.PassphraseCountBelowMinimal;
        }
        if (self.word_count < min_word_count) {
            return Error.WordCountBelowMinimal;
        }
        if (!isAllowedSeparatorCharacter(self.separator)) {
            return Error.SeparatorIsDisallowedCharacter;
        }
    }

    pub const Error = error{
        PassphraseCountBelowMinimal,
        WordCountBelowMinimal,
        SeparatorIsDisallowedCharacter,
    };
};

const min_word_count = 4;
fn isAllowedSeparatorCharacter(c: u8) bool {
    return switch (c) {
        '0'...'9', '-', '=', '_', '.', ',', ' ', '/', ':', ';', '+', '~', '*', '#', '!', '?', '@', '$', '%', '&' => true,
        else => false,
    };
}
