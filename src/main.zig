const std = @import("std");
const build_options = @import("build_options");

const words = @import("words.zig").words;

const Allocator = std.mem.Allocator;
const Args = std.process.Args;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.arena.allocator();
    const rng_impl: std.Random.IoSource = .{ .io = io };
    const rng = rng_impl.interface();

    const args = try parseArgs(init.minimal.args, allocator);
    try args.options.validate();

    if (args.version) {
        const version = std.fmt.comptimePrint("{f}\n", .{build_options.version});
        try std.Io.File.stdout().writeStreamingAll(io, version);
        std.process.exit(0);
    }

    const passphrases = try generatePassphrases(allocator, rng, args.options);

    const buffer = try allocator.alloc(u8, args.options.word_count * 10 * args.options.passphrase_count);
    var stdout_writer = std.Io.File.stdout().writer(io, buffer);
    const stdout = &stdout_writer.interface;
    for (passphrases) |passphrase| {
        try stdout.print("{s}\n", .{passphrase});
    }
    try stdout.flush();
}

pub fn parseArgs(args: Args, allocator: Allocator) ParseArgsError!CliArgs {
    var args_it = try Args.iterateAllocator(args, allocator);
    defer args_it.deinit();

    // `std.process.Args` holds program name as the first entry.
    _ = args_it.next();

    var cli_args = CliArgs{};

    const memeq = std.mem.eql;
    while (args_it.next()) |arg| {
        if (memeq(u8, arg, "--version") or memeq(u8, arg, "-v")) {
            cli_args.version = true;
            break;
        } else if (memeq(u8, arg, "--count") or memeq(u8, arg, "-c")) {
            const passphrase_count_str = args_it.next() orelse return ParseArgsError.MissingValue;
            cli_args.options.passphrase_count = std.fmt.parseInt(usize, passphrase_count_str, 10) catch return ParseArgsError.InvalidValue;
        } else if (memeq(u8, arg, "--words") or memeq(u8, arg, "-w")) {
            const word_count_str = args_it.next() orelse return ParseArgsError.MissingValue;
            cli_args.options.word_count = std.fmt.parseInt(usize, word_count_str, 10) catch return ParseArgsError.InvalidValue;
        } else if (memeq(u8, arg, "--separator") or memeq(u8, arg, "-s")) {
            const separator = args_it.next() orelse return ParseArgsError.MissingValue;
            if (separator.len != 1) return ParseArgsError.InvalidValue;
            cli_args.options.separator = separator[0];
        } else if (std.mem.startsWith(u8, arg, "-")) {
            return ParseArgsError.InvalidOption;
        } else {
            return ParseArgsError.UnexpectedArgument;
        }
    }

    return cli_args;
}

pub const ParseArgsError = error{
    MissingValue,
    InvalidValue,
    InvalidOption,
    UnexpectedArgument,
} || Args.ToSliceError;

pub const CliArgs = struct {
    version: bool = false,
    options: GenerationOptions = .{},
};

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
