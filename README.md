# Cldr Collation

An Elixir implementation of the [Unicode Collation Algorithm](https://www.unicode.org/reports/tr10/) (UCA)
as extended by [CLDR](http://www.unicode.org/reports/tr35/tr35-collation.html), providing
language-aware string sorting and comparison. An opt-in NIF is provided for high performance collating.

## Features

* Full Unicode Collation Algorithm implementation in pure Elixir.

* CLDR root collation based on the Unicode DUCET table.

* Locale-specific tailoring for 10+ languages (Danish, German phonebook, Spanish, Swedish, Finnish, etc.)

* All BCP47 `-u-` extension collation keys supported.

* Optional high-performance NIF backend using ICU4C.

* Sort key generation for efficient repeated comparisons.

## Installation

Add `ex_cldr_collation` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_cldr_collation, "~> 1.0"}
  ]
end
```

### NIF Installation on MacOS

On MacOS, the relevant headers are included in `ex_cldr_collation` and no additional installation is required. The build process will link to the MacOX native `icucore` library.

However it is also possible to use another installation of `libicu` if, for some reason, the native installation is not sufficiently up-to-date.  An installed `icu4c` will take precedence over the native `icucore` library. For example, the following will install `icu4c` (which includes `libicu`), and link it into the standard search path. When compiling, this installation will take precendence.

```bash
% brew install icu4c
% brew link icu4c
# Remove any old build of the NIF that may have been linked to the native icucore lib
% rm ./deps/ex_cldr_collation/priv/ucol.so
% mix deps.compile ex_cldr_collation
```

### NIF Installation on Linux

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

## Example Usage

```elixir
iex> Cldr.Collation.sort(["café", "cafe", "Cafe"])
["cafe", "Cafe", "café"]

# Cased comparisons

iex> Cldr.Collation.sort(["café", "cafe", "Cafe"], case_first: :upper)
["Cafe", "cafe", "café"]

iex> Cldr.Collation.compare("café", "cafe")
:gt

iex> Cldr.Collation.compare("a", "A", casing: :insensitive)
:eq

# Numeric ordering
iex> Cldr.Collation.sort(["Level 10", "Level 2"], numeric: true)
["Level 2", "Level 10"]

iex> Cldr.Collation.sort(["Level 10", "Level 2"], numeric: false)
["Level 10", "Level 2"]

# German phonebook ordering
iex> words = ["Ärger", "Alter", "Ofen", "Öl", "Über", "Ulm"]

iex> Cldr.Collation.sort(words)
["Alter", "Ärger", "Ofen", "Öl", "Über", "Ulm"]

iex> Cldr.Collation.sort(words, locale: "de-u-co-phonebk")
["Ärger", "Alter", "Öl", "Ofen", "Über", "Ulm"]

# Locale-based ordering
iex> Cldr.Collation.compare("a", "A", locale: "en-u-ks-level2")
:eq

# Sort key generation
iex> Cldr.Collation.sort_key("hello")
<<36, 196, 36, 83, 37, 40, 37, 40, 37, 152, 0, 0, 0, 32, 0, 32, 0, 32, 0, 32, 0,
  32, 0, 0, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2>>
```

## Collation Options

The collation options are summarised here. See the [detailed explanation](collation_options.html) for more information about the impact and usage of the various options.

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

The `casing` option is a convenience alias. `casing: :insensitive` is equivalent to `strength: :secondary`.

## NIF Backend

An optional NIF backend using ICU4C is available for high-performance collation.
When compiled, it is used automatically for comparisons and sorting when all
options are NIF-compatible. The pure Elixir implementation is used as a fallback
for features the NIF does not support.

### Setup

1. Install ICU system libraries (`libicu` on Linux). For MacOS, `icucore` is used and is part of the base operating system.
2. Add the `elixir_make` dependency (already included as optional).
3. Compile with the NIF enabled:

```bash
CLDR_COLLATION_NIF=true mix compile
```

Or set it permanently in `config/config.exs`:

```elixir
config :ex_cldr_collation, :nif, true
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

* **NIF**: Calls ICU4C's `ucol_strcollIter()` for pairwise string comparison. Comparison and sorting happen entirely in C with constant memory overhead. Sort keys are not generated — `sort/2` uses pairwise comparisons via `Enum.sort/2`.

* **Elixir**: Generates binary sort keys from the CLDR-modified DUCET table, then compares keys with standard binary operators. `sort/2` pre-computes sort keys for all strings ([Schwartzian transform](https://en.wikipedia.org/wiki/Schwartzian_transform)), making it efficient for large lists but more memory-intensive.

### Known Deviations Between Backends

For NIF-compatible options, both backends produce identical ordering for
common text. The following edge cases may produce different results or
different behavior.

#### Unicode version mismatch

The Elixir backend uses the CLDR FractionalUCA table (UCA 17.0.0). The NIF
backend delegates to the system's ICU library, which may use a different
Unicode version. Characters added or reassigned between Unicode versions
(typically rare or recently encoded codepoints) may sort differently.

To check which ICU version your system provides:

```bash
# macOS (uses icucore)
$ icu-config --version 2>/dev/null || echo "see /usr/lib/libicucore.dylib"

# Linux
$ pkg-config --modversion icu-uc
```

#### Locale tailoring is Elixir-only

Only the Elixir backend applies CLDR locale-specific tailoring rules
(e.g., German phonebook `de-u-co-phonebk`, Swedish `sv`, Danish `da`,
Spanish traditional `es-u-co-trad`). The NIF backend does not load
CLDR tailoring data.

* With `backend: :default`, locale tailoring silently falls back to the Elixir backend.

* With `backend: :nif`, passing a locale that requires tailoring raises an `ArgumentError`.

#### `max_variable` values other than `:punct`

The NIF backend only supports the default `max_variable: :punct`. The
values `:space`, `:symbol`, and `:currency` require the Elixir backend.
With `backend: :default`, non-default values silently fall back to Elixir.

#### `sort_key/2` is always Elixir

Sort keys are generated exclusively by the Elixir backend, regardless of
the `backend` option. The NIF backend uses pairwise ICU comparisons and
does not produce sort keys.

#### Sorting algorithm

The two backends use different sorting strategies:

* **NIF**: Uses `Enum.sort/2` with pairwise ICU comparisons.

* **Elixir**: Pre-computes binary sort keys (Schwartzian transform), then sorts by key with `Enum.sort_by/2`.

Both use Erlang's stable merge sort, so strings that are collation-equal
retain their original input order.

#### Reorder codes

The NIF backend supports a fixed set of ISO 15924 script codes (`:Latn`,
`:Grek`, `:Cyrl`, `:Hani`, `:Hang`, `:Arab`, `:Hebr`, `:Deva`, `:Thai`,
etc.) and special codes (`:space`, `:punct`, `:symbol`, `:currency`,
`:digit`). Unrecognized script codes fall back to Elixir with
`backend: :default` and raise with `backend: :nif`.

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
| Cased, 5-char strings      | 9,460      | 6,420        | 1.47x         |
| Cased, 10-char strings     | 9,410      | 3,710        | 2.54x         |
| Cased, 20-char strings     | 9,420      | 2,070        | 4.55x         |
| Cased, 50-char strings     | 9,330      | 900          | 10.37x        |
| Uncased, 5-char strings    | 2,600      | 8,000        | 0.33x         |
| Uncased, 10-char strings   | 2,570      | 4,460        | 0.58x         |
| Uncased, 20-char strings   | 2,570      | 2,460        | 1.04x         |
| Uncased, 50-char strings   | 2,570      | 990          | 2.60x         |

### Memory per sort call

| Scenario                   | NIF        | Elixir       | NIF vs Elixir |
|----------------------------|:-----------|:-------------|:--------------|
| Cased, 5-char strings      | 54.36 KB   | 223.58 KB    | 0.24x         |
| Cased, 10-char strings     | 53.95 KB   | 417.48 KB    | 0.13x         |
| Cased, 20-char strings     | 54.99 KB   | 797.56 KB    | 0.07x         |
| Cased, 50-char strings     | 52.99 KB   | 1,930.24 KB  | 0.03x         |
| Uncased, 5-char strings    | 54.54 KB   | 186.19 KB    | 0.29x         |
| Uncased, 10-char strings   | 53.92 KB   | 348.09 KB    | 0.15x         |
| Uncased, 20-char strings   | 55.05 KB   | 668.40 KB    | 0.08x         |
| Uncased, 50-char strings   | 53.17 KB   | 1,628.27 KB  | 0.03x         |

### Key Observations

- **NIF throughput is constant** across string lengths (~9,400 ips cased, ~2,570 ips uncased) because ICU processes strings entirely in C.

- **Elixir throughput scales with string length**, from 8,000 ips (5 chars) down to 900 ips (50 chars).

- **NIF is faster for cased comparisons** at all string lengths, and for uncased at 50+ characters.

- **Elixir is faster for uncased strings** up to 20 characters due to lower per-call overhead and the fast Latin lookup path.

- **NIF uses ~54 KB constant memory** regardless of string length, while Elixir allocates 186 KB to 1.9 MB per sort (generating intermediate sort keys and collation elements).

### Possible Future Optimizations

Two additional optimizations from ICU could further improve the Elixir backend:

#### Incremental comparison

ICU's `ucol_strcoll` compares two strings by
processing collation elements from both strings simultaneously, stopping at
the first primary-level difference. Since 90%+ of comparisons resolve at the
primary level, secondary and tertiary weights are never computed. The current
Elixir `compare/3` generates complete sort keys for both strings before
comparing. An incremental comparator would avoid redundant work, especially
for strings that share a long common prefix (common during sorting). However,
this requires restructuring the pipeline from batch (produce all elements,
process variable weights, build key) to streaming (produce element-by-element,
compare as we go), which is a significant refactor. The
[Schwartzian transform](https://en.wikipedia.org/wiki/Schwartzian_transform)
used by `sort/2` would also need rethinking, since it relies on pre-computed
sort keys. The tradeoff: lower memory and faster `compare/3`, but pairwise
comparison in `sort/2` would perform O(n log n) collation walks instead of
O(n) key generations followed by cheap binary comparisons.

#### Sort key compression

In the collation table, 80.5% of secondary weights
are `0x0020` and 70.1% of tertiary weights are `0x0002`. The current sort key
format encodes every weight as 16 bits, wasting a byte on these common values.
ICU uses a common-weight compression scheme
([UTS #10 Section 7.3](https://www.unicode.org/reports/tr10/#Run-Length_Compression))
that encodes the most frequent secondary/tertiary value as a single byte,
roughly halving the L2 and L3 sections. This would reduce sort key size from
~6x to ~4x input string length, lowering memory allocation during sorting.
The tradeoff: compressed keys are a format change — any user persisting sort
keys (e.g., in database indexes) would need to regenerate them. The
performance benefit is primarily reduced memory allocation rather than reduced
CPU, since binary comparison is already fast regardless of key length.

