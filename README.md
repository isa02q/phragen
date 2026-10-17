# Phragen

Phragen is a configurable passphrase generator for the CLI.
It is a Zig port of a similar Go tool I used personally, with some added features.

Phragen generates random passphrases in the Diceware style.
It uses [`std.Random`](https://ziglang.org/documentation/master/std/#std.Random) as a CSPRNG engine, seeded from an I/O source provided by the OS ([`std.process.Init.io`](https://ziglang.org/documentation/master/std/#std.process.Init)).
The wordlist is the [EFF's Large Wordlist](https://www.eff.org/files/2016/07/18/eff_large_wordlist.txt) (7,776 words), which provides 12.9 bits of entropy per word.

This repository loosely tracks the [Zig master branch](https://codeberg.org/ziglang/zig/src/branch/master).

## Installation

### via mise GitHub backend

```bash
mise use --global github:isa02q/phragen
```

### via Scoop

```bash
scoop install https://raw.githubusercontent.com/isa02q/phragen/refs/heads/main/phragen.json
```

### Build from source

This project is built against a Zig's nightly build, which often diverges from the actual Zig master branch.
A recent stable release will most likely build the project as well.
You can also run the build command via [`mise exec`](https://mise.jdx.dev/cli/exec.html) to use exact version of Zig used for the release build without installing it.

If you want to change the optimization strategy or the target, run `zig build --help`.

```bash
git clone https://github.com/isa02q/phragen.git
cd phragen/

# build the release binary in `ReleaseSafe` mode
# the binary is installed to `zig-out/release/`
zig build release --summary all

# build the debug binary
# the binary is installed to `zig-out/bin/`
zig build --summary all
```

### Download from Releases page

Download a binary compatible with your OS and CPU from [GitHub Releases](https://github.com/isa02q/phragen/releases/latest).

## Usage

```txt
Phragen - Configurable passphrase generator

Usage: phragen [OPTIONS]

By default, generates a single passphrase with 6 words and 77 bits of entropy

Options:
  -v, --version             Print version and exit
  -h, --help                Print this help and exit
  -c, --count <int>         Number of passphrases to generate (default: 1, minimum: 1)
  -w, --words <int>         Number of words in the passphrase (default: 6, minimum: 4)
  -s, --separator <value>   Character or keyword used to separate words (default: ".")
                              Supported values:
                                <char>  Use the given character as a separator
                                digit   Use random digits as separators
                                symbol  Use random symbols as separators
                                mix     Use random digits or symbols as separators
                                none    Disable separators
  -C, --capitalize <value>  Capitalization strategy of passphrase
                              Supported values:
                                initial  Capitalize an initial character of each word
                                random   Capitalize random characters
                                all      Capitalize all characters
  -p, --preset <value>      Preset suited to a given purpose. When an option is passed explicitly, it takes precedence
                              Supported values:
                                master  High-entropy passphrase for critical accounts (8 words, 137 bits)
                                pin     Alphanumeric passphrase for PIN-like use cases (4 words, 61 bits)
                                pascal  PascalCase passphrase without separators for everyday use (4 words, 51 bits)
                                super   Extremely high-entropy passphrase, not meant to be memorized (14 words, 244 bits)
  --show-entropy            Calculate and print the entropy of the passphrase. The result includes the randomness of
                            separators, but not of capitalization

```

## Notes

### Instant generation from the dialog (for Windows)

[`generate-and-copy.bat`](./generate-and-copy.bat) copies a generated passphrase to the clipboard, allowing you to generate and paste one without opening a terminal.

Follow these two steps to use it directly from the dialog launched with pressing `Win`+`R`.

1. Make sure `phragen.exe` is on your `PATH` or edit the file to specify the absolute path to `phragen.exe`.
2. Place the script in a directory included in your `PATH`, using any filename you like (a short one is preferable).

## Licensing

The source code is licensed under the [BSD 2-Clause License](./LICENSE).

The wordlist from the [Electronic Frontier Foundation (EFF)](https://www.eff.org/) is licensed under the [Creative Commons Attribution 4.0 International License](https://creativecommons.org/licenses/by/4.0/).
For more info, visit [EFF's Copyright Policy](https://www.eff.org/copyright).

## References

- [The Diceware Passphrase Home Page](https://theworld.com/~reinhold/diceware.html)
- [EFF's Large Wordlist](https://www.eff.org/files/2016/07/18/eff_large_wordlist.txt)
- [An article about passphrases and EFF's wordlists](https://www.eff.org/deeplinks/2016/07/new-wordlists-random-passphrases)
