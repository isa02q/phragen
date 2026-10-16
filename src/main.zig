const std = @import("std");

const cli = @import("cli.zig");

const Allocator = std.mem.Allocator;
const Args = std.process.Args;
const fatal = std.process.fatal;

const help = (
    \\Phragen - Configurable passphrase generator
    \\
    \\Usage: phragen [OPTIONS]
    \\
    \\By default, generates a single passphrase with 6 words and 77 bits of entropy
    \\
    \\Options:
    \\  -v, --version             Print version and exit
    \\  -h, --help                Print this help and exit
    \\  -c, --count <int>         Number of passphrases to generate (default: 1, minimum: 1)
    \\  -w, --words <int>         Number of words in the passphrase (default: 6, minimum: 4)
    \\  -s, --separator <value>   Character or keyword used to separate words (default: ".")
    \\                              Supported values:
    \\                                <char>  Use the given character as a separator
    \\                                digit   Use random digits as separators
    \\                                symbol  Use random symbols as separators
    \\                                mix     Use random digits or symbols as separators
    \\                                none    Disable separators
    \\  -C, --capitalize <value>  Capitalization strategy of passphrase
    \\                              Supported values:
    \\                                initial  Capitalize an initial character of each word
    \\                                random   Capitalize random characters
    \\                                all      Capitalize all characters
    \\  -p, --preset <value>      Preset suited to a given purpose. When an option is passed explicitly, it takes precedence
    \\                              Supported values:
    \\                                master  High-entropy passphrase for critical accounts (8 words, 137 bits)
    \\                                pin     Alphanumeric passphrase for PIN-like use cases (4 words, 61 bits)
    \\                                pascal  PascalCase passphrase without separators for everyday use (4 words, 51 bits)
    \\                                super   Extremely high-entropy passphrase, not meant to be memorized (14 words, 244 bits)
    \\  --show-entropy            Calculate and print the entropy of the passphrase. The result includes the randomness of
    \\                            separators, but not of capitalization
    \\
);

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.arena.allocator();

    const args = try init.minimal.args.toSlice(allocator);
    var error_arg: []const u8 = undefined;

    const cli_args = cli.parseArgs(args, &error_arg) catch |err| {
        switch (err) {
            error.MissingValue => fatal("Option `{s}` requires a value but none was supplied", .{error_arg}),
            error.InvalidValue => fatal("Invalid value for `{s}`", .{error_arg}),
            error.InvalidOption => fatal("Unknown option `{s}`", .{error_arg}),
            error.UnexpectedArgument => fatal("Unexpected argument `{s}`", .{error_arg}),
            else => return err,
        }
    };

    // Handle early exit flags.
    {
        if (cli_args.version) {
            const version = std.fmt.comptimePrint("{f}\n", .{@import("build_options").version});
            try std.Io.File.stdout().writeStreamingAll(io, version);
            std.process.exit(0);
        }

        if (cli_args.help) {
            try std.Io.File.stdout().writeStreamingAll(io, help);
            std.process.exit(0);
        }
    }

    cli_args.options.validate() catch |err| {
        switch (err) {
            error.WordCountBelowMinimum => fatal("A passphrase must contain at least 4 words for security reasons", .{}),
            error.SeparatorIsDisallowedCharacter => fatal("The specified character is not allowed as a separator", .{}),
        }
    };

    // Run the actual passphrase generation logic.
    try cli.run(io, allocator, cli_args);
}

test {
    _ = @import("passphrase.zig");
    _ = @import("cli.zig");
    _ = @import("entropy.zig");
}
