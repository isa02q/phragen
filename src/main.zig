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
    \\Options:
    \\  -v, --version            Print version and exit
    \\  -h, --help               Print this help and exit
    \\  -c, --count <int>        Number of passphrases to generate (default: 1)
    \\  -w, --words <int>        Number of words in the passphrase (default: 6, minimum: 4)
    \\  -s, --separator <value>  Character or keyword used to separate words (default: ".")
    \\                           Supported values:
    \\                             <char>  Use the given character as a separator
    \\                             digit   Use random digits as separators
    \\                             symbol  Use random symbols as separators
    \\                             mix     Use random digits or symbols as separators
    \\                             none    Disable separators
    \\  -p, --preset <value>     Preset suited to a given purpose
    \\                           When an option is passed explicitly, it takes precedence
    \\                           Supported value:
    \\                             master   High-entropy passphrase for critical accounts (8 words, 137 bits)
    \\                             simple   Memorable and typable passphrase for everyday use (6 words, 77 bits)
    \\                             pin      Weak alphanumeric passphrase for PIN-like use cases (4 words, 61 bits)
    \\                             extreme  Extremely high-entropy passphrase, not meant to be memorized (14 words, 244 bits)
    \\  --show-entropy           Calculate and print entropy of the passphrase
    \\
);

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.arena.allocator();

    const args = cli.parseArgs(init.minimal.args, allocator) catch |err| {
        switch (err) {
            error.MissingValue => fatal("A required value is missing for one of the options", .{}),
            error.InvalidValue => fatal("A value for one of the options is invalid", .{}),
            error.InvalidOption => fatal("One of the options is invalid", .{}),
            error.UnexpectedArgument => fatal("A positional argument is unexpected", .{}),
            else => return err,
        }
    };

    // Handle early exit flags.
    {
        if (args.version) {
            const version = std.fmt.comptimePrint("{f}\n", .{@import("build_options").version});
            try std.Io.File.stdout().writeStreamingAll(io, version);
            std.process.exit(0);
        }

        if (args.help) {
            try std.Io.File.stdout().writeStreamingAll(io, help);
            std.process.exit(0);
        }
    }

    args.options.validate() catch |err| {
        switch (err) {
            error.WordCountBelowMinimum => fatal("A passphrase must contain at least 4 words for security reasons", .{}),
            error.SeparatorIsDisallowedCharacter => fatal("The specified character is not allowed as a separator", .{}),
        }
    };

    // Run the actual passphrase generation logic.
    try cli.run(io, allocator, args);
}

test {
    _ = @import("passphrase.zig");
    _ = @import("cli.zig");
    _ = @import("entropy.zig");
}
