const std = @import("std");
const build_options = @import("build_options");
const wordlist = @import("wordlist.zig").wordlist;

const Allocator = std.mem.Allocator;
const Args = std.process.Args;

const help = (
    \\Phragen - Configurable passphrase generator
    \\
    \\Usage: phragen [OPTIONS]
    \\
    \\Options:
    \\  -v, --version           Print version and exit
    \\  -h, --help              Print this help and exit
    \\  -c, --count <int>       Number of passphrases to generate (default: 1)
    \\  -w, --words <int>       Number of words in the passphrase (default: 6, minimum: 4)
    \\  -s, --separator <char>  Character used to separate words (default: ",")
    \\
);

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.arena.allocator();

    const args = parseArgs(init.minimal.args, allocator) catch |err| {
        const message = switch (err) {
            error.MissingValue => "A required value is missing for one of the options",
            error.InvalidValue => "A value for one of the options is invalid",
            error.InvalidOption => "One of the options is invalid",
            error.UnexpectedArgument => "A positional argument is unexpected",
            else => return err,
        };

        printErrorMessage(io, err, message);
    };

    args.options.validate() catch |err| {
        const message = switch (err) {
            error.PassphraseCountBelowMinimum => "The number of passphrases to generate must be at least 1",
            error.WordCountBelowMinimum => "A passphrase must contain at least 4 words for security reasons",
            error.SeparatorIsDisallowedCharacter => "The specified character is not allowed as a separator",
        };

        printErrorMessage(io, err, message);
    };

    if (args.version) {
        const version = std.fmt.comptimePrint("{f}\n", .{build_options.version});
        try std.Io.File.stdout().writeStreamingAll(io, version);
        std.process.exit(0);
    }

    if (args.help) {
        try std.Io.File.stdout().writeStreamingAll(io, help);
        std.process.exit(0);
    }

    const rng_impl: std.Random.IoSource = .{ .io = io };
    const rng = rng_impl.interface();
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
        } else if (memeq(u8, arg, "--help") or memeq(u8, arg, "-h")) {
            cli_args.help = true;
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
    help: bool = false,
    options: GenerationOptions = .{},
};

pub const GenerationOptions = struct {
    passphrase_count: usize = 1,
    word_count: usize = 6,
    separator: u8 = ',',

    pub fn validate(self: GenerationOptions) Error!void {
        if (self.passphrase_count < 1) {
            return Error.PassphraseCountBelowMinimum;
        }
        if (self.word_count < min_word_count) {
            return Error.WordCountBelowMinimum;
        }
        if (!isAllowedSeparatorCharacter(self.separator)) {
            return Error.SeparatorIsDisallowedCharacter;
        }
    }

    pub const Error = error{
        PassphraseCountBelowMinimum,
        WordCountBelowMinimum,
        SeparatorIsDisallowedCharacter,
    };
};

const min_word_count = 4;

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
    const firstword_index = rng.uintLessThan(usize, wordlist.len);
    try list.appendSlice(allocator, wordlist[firstword_index]);

    for (1..opt.word_count) |_| {
        try list.append(allocator, opt.separator);
        const index = rng.uintLessThan(usize, wordlist.len);
        try list.appendSlice(allocator, wordlist[index]);
    }

    return list.toOwnedSlice(allocator);
}

fn isAllowedSeparatorCharacter(c: u8) bool {
    return switch (c) {
        '0'...'9', '-', '=', '_', '.', ',', ' ', '/', ':', ';', '+', '~', '*', '#', '!', '?', '@', '$', '%', '&' => true,
        else => false,
    };
}

fn printErrorMessage(io: std.Io, err: anyerror, message: []const u8) noreturn {
    const file = std.Io.File.stderr();
    var buffer: [128]u8 = undefined;
    var stderr_writer = file.writer(io, &buffer);
    const stderr = &stderr_writer.interface;

    const supports_ansi = file.supportsAnsiEscapeCodes(io) catch false;
    if (supports_ansi) {
        // Print `error:` in bold red.
        stderr.print("\x1b[1;31merror:\x1b[0m {s}\n", .{@errorName(err)}) catch {};
    } else {
        stderr.print("error: {s}\n", .{@errorName(err)}) catch {};
    }
    stderr.print("{s}\n", .{message}) catch {};
    stderr.flush() catch {};

    std.process.exit(1);
}
