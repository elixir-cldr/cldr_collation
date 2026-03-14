# Cldr Collation

An Elixir implementation of the [Unicode Collation Algorithm](https://www.unicode.org/reports/tr10/) (UCA)
as extended by [CLDR](http://www.unicode.org/reports/tr35/tr35-collation.html), providing
language-aware string sorting and comparison.

## Features

- Full Unicode Collation Algorithm implementation in pure Elixir
- CLDR root collation based on the Unicode DUCET table
- Locale-specific tailoring for 10+ languages (Danish, German phonebook, Spanish, Swedish, Finnish, etc.)
- All BCP47 `-u-` extension collation keys supported
- Optional high-performance NIF backend using ICU4C
- Sort key generation for efficient repeated comparisons

## Installation

Add `cldr_collation` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cldr_collation, "~> 0.1.0"}
  ]
end
```

## Usage

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
When compiled, it is used automatically for simple comparisons (root DUCET with
case-sensitive or case-insensitive strength). Advanced options (locale tailoring,
reordering, numeric, etc.) always use the pure Elixir implementation.

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
| Cased, 5-char strings      | 2,670      | 4,050        | 0.66x         |
| Cased, 10-char strings     | 2,650      | 2,290        | 1.16x         |
| Cased, 20-char strings     | 2,640      | 1,200        | 2.20x         |
| Cased, 50-char strings     | 2,670      | 500          | 5.34x         |
| Uncased, 5-char strings    | 1,520      | 4,790        | 0.32x         |
| Uncased, 10-char strings   | 1,510      | 2,470        | 0.61x         |
| Uncased, 20-char strings   | 1,520      | 1,320        | 1.15x         |
| Uncased, 50-char strings   | 1,530      | 540          | 2.83x         |

### Memory per sort call

| Scenario                   | NIF        | Elixir       | NIF vs Elixir |
|----------------------------|:-----------|:-------------|:--------------|
| Cased, 5-char strings      | 11.80 KB   | 270.58 KB    | 0.04x         |
| Cased, 10-char strings     | 11.92 KB   | 509.37 KB    | 0.02x         |
| Cased, 20-char strings     | 11.91 KB   | 982.90 KB    | 0.01x         |
| Cased, 50-char strings     | 10.33 KB   | 2,401.95 KB  | 0.004x        |
| Uncased, 5-char strings    | 11.74 KB   | 232.14 KB    | 0.05x         |
| Uncased, 10-char strings   | 12.09 KB   | 440.67 KB    | 0.03x         |
| Uncased, 20-char strings   | 12.07 KB   | 852.83 KB    | 0.01x         |
| Uncased, 50-char strings   | 10.49 KB   | 2,089.58 KB  | 0.005x        |

### Key Observations

- **NIF throughput is constant** across string lengths (~2,650 ips cased, ~1,520 ips uncased) because ICU processes strings entirely in C.
- **Elixir throughput scales with string length**, from 4,790 ips (5 chars) down to 500 ips (50 chars).
- **NIF is faster at 20+ characters** for cased comparisons and at 50+ characters for uncased.
- **Elixir is faster for short strings** (5-10 chars) due to lower per-call overhead (no NIF boundary crossing).
- **NIF uses ~12 KB constant memory** regardless of string length, while Elixir allocates 232 KB to 2.4 MB per sort (generating intermediate sort keys and collation elements).

## License

Apache-2.0
