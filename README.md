# Cldr Collation

An Elixir implementation of the [Unicode Collation Algorithm](https://www.unicode.org/reports/tr10/) (UCA)
as extended by [CLDR](http://www.unicode.org/reports/tr35/tr35-collation.html), providing
language-aware string sorting and comparison.

## Installation

`ex_cldr_collation` depends upon [libicu](https://unicode-org.github.io/icu/userguide/icu/) to provide the underlying collator. There are two required components:

* At *build* time (compilation), the `libicu` development headers are are required. On MacOS these headers are provided as part of the library. For Linux systems the package typically called `libicu-dev` is required.

* At *runtime* the `libicu` library is required. On MacOS and Ubuntu this library is delivered as part of the OS. For Alpine and Debian the `icu` package needs to be installed.

### Installation on MacOS

On MacOS, the relevant headers are included in `ex_cldr_collation` and no additional installation is required. The build process will link to the MacOX native `icucore` library.

However it is also possible to use another installation of `libicu` if, for some reason, the native installation is not sufficiently up-to-date.  An installed `icu4c` will take precedence over the native `icucore` library. For example, the following will install `icu4c` (which includes `libicu`), and link it into the standard search path. When compiling, this installation will take precendence.

```bash
% brew install icu4c
% brew link icu4c
# Remove any old build of the NIF that may have been linked to the native icucore lib
% rm ./deps/ex_cldr_collation/priv.ucol.so
% mix deps.compile ex_cldr_collation
```

### Installation on Linux

On Linux systems, `libicu-dev`, `libicu` and `pkg-conf` must be installed and well as basic development tools for the build process.

```bash
# For Ubuntu
# pkg-config and libicu are required for compiling the NIF;
# assumes libicu is already installed which is normal on Ubuntu
$ sudo apt-get install build-essential libicu-dev

# For Debian
# pkg-config and icu-dev are required when compiling the NIF;
# libicu is required at runtime
# Debian Bullseye
$ sudo apt install build-essential libicu-dev libicu67
# Debian Bookworm
$ sudo apt install build-essential libicu-dev libicu72

# For Alpine
# erlang-dev and icu-dev are required when compiling the NIF;
# icu is required at runtime
$ apk add build-base icu-dev erlang-dev

# Then check that the libicu package dependencies
# can be resolved
$ pkg-config --libs icu-uc icu-io
-licuio -licui18n -licuuc -licudata
```

## Features

- Full Unicode Collation Algorithm implementation in pure Elixir
- CLDR root collation based on the Unicode DUCET table
- Locale-specific tailoring for 10+ languages (Danish, German phonebook, Spanish, Swedish, Finnish, etc.)
- All BCP47 `-u-` extension collation keys supported
- Optional high-performance NIF backend using ICU4C
- Sort key generation for efficient repeated comparisons

## Installation

Add `cldr_collation` to your list of dependencies in `mix.exs`:
>>>>>>> c/main

```elixir
def deps do
  [
    {:cldr_collation, "~> 0.1.0"}
  ]
end
```

## Examples

```elixir
# Sort a list of strings
Cldr.Collation.sort(["café", "cafe", "Cafe"])
#=> ["cafe", "Cafe", "café"]

# Compare two strings
Cldr.Collation.compare("café", "cafe")
#=> :gt

# Case-insensitive comparison
Cldr.Collation.compare("a", "A", casing: :insensitive)
#=> :eq

# With BCP47 locale
Cldr.Collation.compare("a", "A", locale: "en-u-ks-level2")
#=> :eq

# Use as an Enum.sort comparator
Enum.sort(["c", "a", "b"], Cldr.Collation.Sensitive)
#=> ["a", "b", "c"]

# Generate sort keys for efficient batch comparisons
key = Cldr.Collation.sort_key("hello")
```

## Options

| Option          | Values                                                       | Default            |
|-----------------|--------------------------------------------------------------|:-------------------|
| `strength`      | `:primary`, `:secondary`, `:tertiary`, `:quaternary`, `:identical` | `:tertiary`  |
| `alternate`     | `:non_ignorable`, `:shifted`                                 | `:non_ignorable`   |
| `backwards`     | `true`, `false`                                              | `false`            |
| `normalization` | `true`, `false`                                              | `false`            |
| `case_level`    | `true`, `false`                                              | `false`            |
| `case_first`    | `:upper`, `:lower`, `false`                                  | `false`            |
| `numeric`       | `true`, `false`                                              | `false`            |
| `reorder`       | list of script codes                                         | `[]`               |
| `max_variable`  | `:space`, `:punct`, `:symbol`, `:currency`                   | `:punct`           |
| `casing`        | `:sensitive`, `:insensitive`                                 | (tertiary default) |
| `backend`       | `:default`, `:nif`, `:elixir`                                | `:default`         |
| `locale`        | BCP47 string (e.g., `"da"`, `"en-u-ks-level2"`)             | `nil`              |

The `casing` option is a convenience alias compatible with `ex_cldr_collation`:
`casing: :insensitive` is equivalent to `strength: :secondary`.

## NIF Backend

An optional NIF backend using ICU4C is available for high-performance collation.
When compiled, it is used automatically for comparisons and sorting when all
options are NIF-compatible. The pure Elixir implementation is used as a fallback
for features the NIF does not support.

### Enabling the NIF

Requires ICU system libraries (`libicu` or `icucore` on macOS):

```bash
# macOS: icucore is included with the OS, no extra install needed
# Linux: sudo apt-get install libicu-dev

CLDR_COLLATION_NIF=true mix compile
```

### Backend Selection

| `backend` value | Behavior |
|-----------------|----------|
| `:default`      | Uses NIF if available and options are NIF-compatible, otherwise pure Elixir |
| `:nif`          | Requires NIF; raises if unavailable or options are incompatible |
| `:elixir`       | Always uses pure Elixir, even if NIF is available |

```elixir
# Explicit NIF
Cldr.Collation.sort(strings, backend: :nif, casing: :sensitive)

# Explicit Elixir
Cldr.Collation.sort(strings, backend: :elixir)

# Automatic (default) — NIF when possible
Cldr.Collation.sort(strings)
```

### NIF vs Elixir Feature Support

Both backends implement the Unicode Collation Algorithm and produce identical
results for all NIF-compatible option combinations. The table below summarizes
which features each backend supports.

| Feature                    | NIF | Elixir | Notes |
|----------------------------|:---:|:------:|-------|
| `strength` (all 5 levels)  | yes | yes    |       |
| `alternate` (shifted)      | yes | yes    |       |
| `backwards` (French accents) | yes | yes  |       |
| `case_first` (upper/lower) | yes | yes    |       |
| `case_level`               | yes | yes    |       |
| `normalization`            | yes | yes    |       |
| `numeric`                  | yes | yes    |       |
| `reorder` (recognized scripts) | yes | yes |     |
| `reorder` (unrecognized scripts) | no | yes | NIF falls back to Elixir with `backend: :default` |
| `max_variable` (non-default) | no | yes  | NIF only supports the default `:punct` |
| Locale tailoring           | no  | yes    | e.g., Spanish ñ, German phonebook, Danish æøå |
| `sort_key/2`               | no  | yes    | Sort keys are always generated by the Elixir backend |

When using `backend: :default`, the library automatically falls back to Elixir
for unsupported options. With `backend: :nif`, unsupported options raise an
`ArgumentError`.

### How Each Backend Works

The two backends use fundamentally different approaches:

- **NIF**: Calls ICU4C's `ucol_strcollIter()` for pairwise string comparison.
  Comparison and sorting happen entirely in C with constant memory overhead.
  Sort keys are not generated — `sort/2` uses pairwise comparisons via
  `Enum.sort/2`.

- **Elixir**: Generates binary sort keys from the CLDR-modified DUCET table,
  then compares keys with standard binary operators. `sort/2` pre-computes
  sort keys for all strings ([Schwartzian transform](https://en.wikipedia.org/wiki/Schwartzian_transform)),
  making it efficient for large lists but more memory-intensive.

### Potential Result Differences

For NIF-compatible options, both backends produce identical ordering. However,
differences may arise in edge cases:

- **ICU version mismatch**: The Elixir backend uses the CLDR allkeys table
  (UCA 17.0.0). If the system ICU library uses a different Unicode version,
  rare codepoints may sort differently between backends.
- **Locale tailoring**: Only the Elixir backend applies CLDR locale-specific
  rules. Using `backend: :nif` with a locale that has tailoring rules will
  raise an error; `backend: :default` will silently fall back to Elixir.

## Benchmarks

Sorting 100 random Unicode strings (Latin, accented Latin, Greek, Cyrillic)
at varying lengths. Measured on Apple M1 Max, 64 GB RAM, Elixir 1.19.5, OTP 28.

Run benchmarks with:

```bash
CLDR_COLLATION_NIF=true mix compile && mix run bench/sort_benchmark.exs
```

### Throughput (iterations/second)

| Scenario                   | NIF (ips)  | Elixir (ips) | NIF vs Elixir |
|----------------------------|:-----------|:-------------|:--------------|
| Cased, 5-char strings      | 9,300      | 4,330        | 2.15x         |
| Cased, 10-char strings     | 9,260      | 2,460        | 3.76x         |
| Cased, 20-char strings     | 9,100      | 1,320        | 6.89x         |
| Cased, 50-char strings     | 9,190      | 560          | 16.41x        |
| Uncased, 5-char strings    | 2,560      | 5,100        | 0.50x         |
| Uncased, 10-char strings   | 2,530      | 2,720        | 0.93x         |
| Uncased, 20-char strings   | 2,520      | 1,470        | 1.71x         |
| Uncased, 50-char strings   | 2,550      | 590          | 4.32x         |

### Memory per sort call

| Scenario                   | NIF        | Elixir       | NIF vs Elixir |
|----------------------------|:-----------|:-------------|:--------------|
| Cased, 5-char strings      | 54.36 KB   | 263.02 KB    | 0.21x         |
| Cased, 10-char strings     | 53.95 KB   | 494.39 KB    | 0.11x         |
| Cased, 20-char strings     | 54.99 KB   | 952.35 KB    | 0.06x         |
| Cased, 50-char strings     | 52.99 KB   | 2,319.91 KB  | 0.02x         |
| Uncased, 5-char strings    | 54.54 KB   | 224.52 KB    | 0.24x         |
| Uncased, 10-char strings   | 53.92 KB   | 425.41 KB    | 0.13x         |
| Uncased, 20-char strings   | 55.05 KB   | 824.29 KB    | 0.07x         |
| Uncased, 50-char strings   | 53.17 KB   | 2,017.65 KB  | 0.03x         |

### Key Observations

- **NIF throughput is constant** across string lengths (~9,200 ips cased, ~2,550 ips uncased) because ICU processes strings entirely in C.
- **Elixir throughput scales with string length**, from 5,100 ips (5 chars) down to 560 ips (50 chars).
- **NIF is faster for cased comparisons** at all string lengths, and for uncased at 20+ characters.
- **Elixir is faster for short uncased strings** (5-10 chars) due to lower per-call overhead (no NIF boundary crossing).
- **NIF uses ~54 KB constant memory** regardless of string length, while Elixir allocates 225 KB to 2.3 MB per sort (generating intermediate sort keys and collation elements).

## License

Apache-2.0
