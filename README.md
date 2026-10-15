# Phragen

Phragen is a configurable passphrase generator for CLI.
It is a Zig port of a similar Go tool I used personally, with some added features.

Phragen generates random passphrases in the Diceware style.
It uses an engine ([`std.Random`](https://ziglang.org/documentation/master/std/#std.Random)) as a CSPRNG, seeded from an OS-provided I/O source ([`std.process.Init.io`](https://ziglang.org/documentation/master/std/#std.process.Init)).
The wordlist is the [EFF's Large Wordlist](https://www.eff.org/files/2016/07/18/eff_large_wordlist.txt) (7,776 words), which gives 12.9 bits of entropy per word.

## Installation

### via mise GitHub backend

```bash
mise use --global github:isa02q/phragen
```

### via Scoop

```bash
scoop install https://raw.githubusercontent.com/isa02q/phragen/raw/refs/heads/main/scoop-manifest.json
```

### build from source

Zig 0.17.0 is required.

You can change the optimization strategy and the build target. Run `zig build --help` for details.

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

## Licensing

The source code is licensed under the [BSD 2-Clause License](./LICENSE).

The wordlist from the [Electronic Frontier Foundation (EFF)](https://www.eff.org/) is licensed under the [Creative Commons Attribution 4.0 International License](https://creativecommons.org/licenses/by/4.0/).
For more info, visit [EFF's Copyright Policy](https://www.eff.org/copyright).

## References

- [The Diceware Passphrase Home Page](https://theworld.com/~reinhold/diceware.html)
- [EFF's Large Wordlist](https://www.eff.org/files/2016/07/18/eff_large_wordlist.txt)
- [An article about passphrases and EFF's wordlists](https://www.eff.org/deeplinks/2016/07/new-wordlists-random-passphrases)
