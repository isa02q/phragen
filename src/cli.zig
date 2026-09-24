const std = @import("std");

const passphrase = @import("passphrase.zig");
const wordlist = @import("wordlist.zig");

const Args = std.process.Args;
const Allocator = std.mem.Allocator;

pub fn run(
    io: std.Io,
    allocator: Allocator,
    args: CliArgs,
) RunError!void {
    const rng_impl: std.Random.IoSource = .{ .io = io };
    const rng = rng_impl.interface();

    const passphrases = blk: {
        var list: std.ArrayList([]u8) = .empty;
        errdefer {
            for (list.items) |item| allocator.free(item);
            list.deinit(allocator);
        }

        for (0..args.passphrase_count) |_| {
            const result = try passphrase.generatePassphrase(allocator, rng, args.options);
            try list.append(allocator, result);
        }

        break :blk try list.toOwnedSlice(allocator);
    };

    const buffer_size = // Enough size, including the separator, entropy printing and newline char.
        (args.options.word_count * wordlist.max_word_length * args.passphrase_count) + args.passphrase_count + (args.options.word_count - 1) + 100;
    const buffer = try allocator.alloc(u8, buffer_size);
    var stdout_writer = std.Io.File.stdout().writer(io, buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    if (args.show_entropy) {
        const result = @import("entropy.zig").calculateEntropy(args.options, wordlist.wordlist.len);
        try stdout.print(
            "A {d}-word passphrase has {d:.3} bits of entropy (includes separator randomness)\n\n",
            .{ args.options.word_count, result },
        );
    }

    for (passphrases) |item| {
        try stdout.print("{s}\n", .{item});
    }
}

const RunError = Allocator.Error || std.Io.Writer.Error;

pub fn parseArgs(args: Args, allocator: Allocator) ParseArgsError!CliArgs {
    var args_it = try Args.iterateAllocator(args, allocator);
    defer args_it.deinit();

    // `std.process.Args` holds program name as the first entry.
    _ = args_it.next();

    var cli_args: CliArgs = .{};

    var is_set = struct {
        word_count: bool = false,
        separator: bool = false,
        capitalize: bool = false,
    }{};

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
            const passphrase_count = std.fmt.parseInt(usize, passphrase_count_str, 10) catch return ParseArgsError.InvalidValue;
            if (passphrase_count == 0) return ParseArgsError.InvalidValue;
            cli_args.passphrase_count = passphrase_count;
        } else if (memeq(u8, arg, "--words") or memeq(u8, arg, "-w")) {
            const word_count_str = args_it.next() orelse return ParseArgsError.MissingValue;
            cli_args.options.word_count = std.fmt.parseInt(usize, word_count_str, 10) catch return ParseArgsError.InvalidValue;
            is_set.word_count = true;
        } else if (memeq(u8, arg, "--separator") or memeq(u8, arg, "-s")) {
            const separator_str = args_it.next() orelse return ParseArgsError.MissingValue;
            if (separator_str.len == 1) {
                cli_args.options.separator = .{ .fixed = separator_str[0] };
            } else if (passphrase.Separator.keywords.get(separator_str)) |value| {
                cli_args.options.separator = value;
            } else {
                return ParseArgsError.InvalidValue;
            }
            is_set.separator = true;
        } else if (memeq(u8, arg, "--preset") or memeq(u8, arg, "-p")) {
            const preset_str = args_it.next() orelse return ParseArgsError.MissingValue;
            if (passphrase.Preset.keywords.get(preset_str)) |value| {
                const opt = value.options();
                if (!is_set.word_count) cli_args.options.word_count = opt.word_count;
                if (!is_set.separator) cli_args.options.separator = opt.separator;
                if (!is_set.capitalize) cli_args.options.capitalize = opt.capitalize;
            } else {
                return ParseArgsError.InvalidValue;
            }
        } else if (memeq(u8, arg, "--capitalize") or memeq(u8, arg, "-C")) {
            const capitalize_str = args_it.next() orelse return ParseArgsError.MissingValue;
            if (passphrase.CapitalizeStrategy.keywords.get(capitalize_str)) |value| {
                cli_args.options.capitalize = value;
                is_set.capitalize = true;
            } else {
                return ParseArgsError.InvalidValue;
            }
        } else if (memeq(u8, arg, "--show-entropy")) {
            cli_args.show_entropy = true;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            return ParseArgsError.InvalidOption;
        } else {
            return ParseArgsError.UnexpectedArgument;
        }
    }

    return cli_args;
}

const CliArgs = struct {
    version: bool = false,
    help: bool = false,
    show_entropy: bool = false,
    passphrase_count: usize = 1,
    options: passphrase.GenerationOptions = .{},
};

const ParseArgsError = error{
    MissingValue,
    InvalidValue,
    InvalidOption,
    UnexpectedArgument,
} || Args.ToSliceError;

fn testParseArgs(
    cmd: []const [*:0]const u8,
    expected: CliArgs,
) !void {
    const args: Args = .{ .vector = cmd };
    const cli_args = parseArgs(args, std.testing.allocator);

    try std.testing.expectEqual(expected, cli_args);
}

test "Valid args are parsed correctly" {
    try testParseArgs(&.{ "phragen", "--version", "--count", "2" }, .{ .version = true });
    try testParseArgs(&.{ "phragen", "-h" }, .{ .help = true, .options = .{ .separator = .{ .fixed = '.' } } });
    try testParseArgs(&.{ "phragen", "--count", "5" }, .{ .passphrase_count = 5 });
    try testParseArgs(&.{ "phragen", "--words", "8", "-s", "_" }, .{ .options = .{ .word_count = 8, .separator = .{ .fixed = '_' } } });
    try testParseArgs(&.{ "phragen", "-s", "digit" }, .{ .options = .{ .separator = .digit } });
    try testParseArgs(&.{ "phragen", "--preset", "master" }, .{ .options = .{ .word_count = 8, .separator = .mix } });
    try testParseArgs(&.{ "phragen", "-s", "!", "-p", "pin", "-w", "8" }, .{ .options = .{ .word_count = 8, .separator = .{ .fixed = '!' } } });
    try testParseArgs(&.{ "phragen", "-c", "10", "--words", "7", "--separator", "symbol" }, .{ .passphrase_count = 10, .options = .{ .word_count = 7, .separator = .symbol } });
    try testParseArgs(&.{ "phragen", "--capitalize", "all", "--show-entropy" }, .{ .show_entropy = true, .options = .{ .capitalize = .all } });
    try testParseArgs(&.{ "phragen", "-c", "2", "-C", "initial" }, .{ .passphrase_count = 2, .options = .{ .capitalize = .initial } });
}

fn testParseArgsError(
    cmd: []const [*:0]const u8,
    expected: ParseArgsError,
) !void {
    const args: Args = .{ .vector = cmd };
    const result = parseArgs(args, std.testing.allocator);

    try std.testing.expectError(expected, result);
}

test "Invalid args return an expected error" {
    try testParseArgsError(&.{ "phragen", "--count", "!" }, ParseArgsError.InvalidValue);
    try testParseArgsError(&.{ "phragen", "-c", "0" }, ParseArgsError.InvalidValue);
    try testParseArgsError(&.{ "phragen", "-s", "string" }, ParseArgsError.InvalidValue);
    try testParseArgsError(&.{ "phragen", "-C", "none" }, ParseArgsError.InvalidValue);
    try testParseArgsError(&.{ "phragen", "--separator", "charset" }, ParseArgsError.InvalidValue);
    try testParseArgsError(&.{ "phragen", "--preset", "login" }, ParseArgsError.InvalidValue);
    try testParseArgsError(&.{ "phragen", "--separator" }, ParseArgsError.MissingValue);
    try testParseArgsError(&.{ "phragen", "-w" }, ParseArgsError.MissingValue);
    try testParseArgsError(&.{ "phragen", "--word", "10" }, ParseArgsError.InvalidOption);
    try testParseArgsError(&.{ "phragen", "hello" }, ParseArgsError.UnexpectedArgument);
}
