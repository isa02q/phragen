const std = @import("std");

const passphrase = @import("passphrase.zig");

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

        for (0..args.options.passphrase_count) |_| {
            const result = try passphrase.generatePassphrase(allocator, rng, args.options);
            try list.append(allocator, result);
        }

        break :blk try list.toOwnedSlice(allocator);
    };

    const buffer = try allocator.alloc(u8, args.options.word_count * 10 * args.options.passphrase_count);
    var stdout_writer = std.Io.File.stdout().writer(io, buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    if (args.show_entropy) {
        const result = @import("entropy.zig").calculateEntropy(args.options, @import("wordlist.zig").wordlist.len);
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
            const separator_str = args_it.next() orelse return ParseArgsError.MissingValue;
            if (separator_str.len == 1) {
                cli_args.options.separator = .{ .fixed = separator_str[0] };
            } else if (passphrase.Separator.keywords.get(separator_str)) |value| {
                cli_args.options.separator = value;
            } else {
                return ParseArgsError.InvalidValue;
            }
        } else if (memeq(u8, arg, "--preset") or memeq(u8, arg, "-p")) {
            const preset_str = args_it.next() orelse return ParseArgsError.MissingValue;
            if (passphrase.Preset.keywords.get(preset_str)) |value| {
                cli_args.options = value.options();
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
    options: passphrase.GenerationOptions = .{},
};

const ParseArgsError = error{
    MissingValue,
    InvalidValue,
    InvalidOption,
    UnexpectedArgument,
} || Args.ToSliceError;

test "parseArgs(): valid args are parsed correctly" {
    const cases = [_]struct {
        cmd: []const [*:0]const u8,
        expected: CliArgs,
    }{
        .{ .cmd = &.{ "phragen", "--version" }, .expected = .{ .version = true } },
        .{ .cmd = &.{ "phragen", "-v", "--count", "2" }, .expected = .{ .version = true } },
        .{ .cmd = &.{ "phragen", "--help" }, .expected = .{ .help = true } },
        .{ .cmd = &.{ "phragen", "-c", "5" }, .expected = .{ .version = false, .options = .{ .passphrase_count = 5 } } },
        .{ .cmd = &.{ "phragen", "--count", "10" }, .expected = .{ .options = .{ .passphrase_count = 10 } } },
        .{ .cmd = &.{ "phragen", "--words", "20" }, .expected = .{ .options = .{ .word_count = 20 } } },
        .{ .cmd = &.{ "phragen", "-w", "4" }, .expected = .{ .options = .{ .word_count = 4 } } },
        .{ .cmd = &.{ "phragen", "--separator", "-" }, .expected = .{ .options = .{ .separator = .{ .fixed = '-' } } } },
        .{ .cmd = &.{ "phragen", "-s", "!" }, .expected = .{ .options = .{ .separator = .{ .fixed = '!' } } } },
        .{ .cmd = &.{ "phragen", "-w", "12", "--separator", "^" }, .expected = .{ .options = .{ .word_count = 12, .separator = .{ .fixed = '^' } } } },
        .{ .cmd = &.{ "phragen", "-s", "digit", "-w", "8" }, .expected = .{ .options = .{ .word_count = 8, .separator = .digit } } },
        .{ .cmd = &.{ "phragen", "--preset", "master" }, .expected = .{ .options = .{ .word_count = 8, .separator = .mix } } },
        .{ .cmd = &.{ "phragen", "-p", "pin4" }, .expected = .{ .options = .{ .word_count = 4, .separator = .digit } } },
    };

    for (cases) |case| {
        const args: Args = .{ .vector = case.cmd };
        const cli_args = try parseArgs(args, std.testing.allocator);

        try std.testing.expectEqual(case.expected, cli_args);
    }
}

test "parseArgs(): fails with expected error when invalid args passed" {
    const cases = [_]struct {
        cmd: []const [*:0]const u8,
        expectedError: ParseArgsError,
    }{
        .{ .cmd = &.{ "phragen", "--count", "!" }, .expectedError = ParseArgsError.InvalidValue },
        .{ .cmd = &.{ "phragen", "--separator" }, .expectedError = ParseArgsError.MissingValue },
        .{ .cmd = &.{ "phragen", "--separator", "number" }, .expectedError = ParseArgsError.InvalidValue },
        .{ .cmd = &.{ "phragen", "-w" }, .expectedError = ParseArgsError.MissingValue },
        .{ .cmd = &.{ "phragen", "-w", "!" }, .expectedError = ParseArgsError.InvalidValue },
        .{ .cmd = &.{ "phragen", "-s", "??" }, .expectedError = ParseArgsError.InvalidValue },
        .{ .cmd = &.{ "phragen", "--word", "5" }, .expectedError = ParseArgsError.InvalidOption },
        .{ .cmd = &.{ "phragen", "--happy" }, .expectedError = ParseArgsError.InvalidOption },
        .{ .cmd = &.{ "phragen", "hello" }, .expectedError = ParseArgsError.UnexpectedArgument },
    };

    for (cases) |case| {
        const args: Args = .{ .vector = case.cmd };
        const result = parseArgs(args, std.testing.allocator);

        try std.testing.expectError(case.expectedError, result);
    }
}
