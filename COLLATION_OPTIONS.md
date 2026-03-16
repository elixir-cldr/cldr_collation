# How Collation Options Affect Sort Order

This document shows how each option to `Cldr.Collation.compare/3` and
`Cldr.Collation.sort/2` affects the ordering of strings. All examples
use the pure Elixir backend (`backend: :elixir`).

For a thorough introduction to the Unicode Collation Algorithm and
locale-aware sorting, see:

* [ICU Collation User Guide](https://unicode-org.github.io/icu/userguide/collation/)
* [UTS #10: Unicode Collation Algorithm](https://www.unicode.org/reports/tr10/)
* [LDML Part 5: Collation](https://www.unicode.org/reports/tr35/tr35-collation.html)

## Example word list

The following 10 words are used throughout this document unless noted otherwise:

```
cafe  café  Café  co-op  naive  naïve  résumé  Résumé  TR35  UTS10
```

This list includes mixed case (`cafe` / `Café`), accented characters
(`café`, `naïve`, `résumé`), punctuation (`co-op`), and embedded
digits (`TR35`, `UTS10`).

## Default sort order

With no options (equivalent to `strength: :tertiary, alternate: :non_ignorable`),
the collation algorithm considers base letters first (primary), then
accents (secondary), then case (tertiary):

```
cafe | café | Café | co-op | naive | naïve | résumé | Résumé | TR35 | UTS10
```

Key observations:

* `cafe` before `café` — the unaccented form sorts first (secondary difference).
* `café` before `Café` — lowercase before uppercase (tertiary difference).
* `co-op` sorts between `café` and `naive` — the hyphen has a primary weight.
* `TR35` before `UTS10` — digits are compared character-by-character, so `3` < `1` never applies; `T` < `U` decides it at the primary level.

---

## Strength

The `strength` option controls how many levels of difference are significant.

### `:primary` — base letters only

Ignores both accents and case. Equivalent to `:ignore_accents`.

```elixir
Cldr.Collation.compare("cafe", "café", strength: :primary)   # => :eq
Cldr.Collation.compare("cafe", "Café", strength: :primary)   # => :eq
```

At primary strength, `cafe`, `café`, and `Café` are all considered equal
because they share the same base letters.

### `:secondary` — base letters + accents

Ignores case but distinguishes accents. Equivalent to `:ignore_case`.

```elixir
Cldr.Collation.compare("cafe", "café", strength: :secondary)   # => :lt  (accent matters)
Cldr.Collation.compare("cafe", "Café", strength: :secondary)   # => :lt  (accent matters, case ignored)
```

### `:tertiary` — base letters + accents + case (default)

Distinguishes base letters, accents, and case:

```elixir
Cldr.Collation.compare("café", "Café", strength: :tertiary)   # => :lt  (lowercase before uppercase)
```

### `:quaternary` — adds punctuation distinction under shifted mode

Only meaningful when combined with `alternate: :shifted`. See the
`alternate` section below.

### `:identical` — full codepoint-level distinction

After all collation levels, compares the NFD-normalized codepoint sequences.
Two strings are `:eq` at `:identical` strength only if they are codepoint-for-codepoint
the same after normalization.

---

## Alternate (variable weight handling)

The `alternate` option controls how "variable" characters — spaces,
punctuation, and symbols — are treated.

### `:non_ignorable` (default)

Variable characters have primary weights and affect sort order:

```elixir
Cldr.Collation.compare("co-op", "coop")                       # => :lt  (hyphen has weight)
Cldr.Collation.compare("de luge", "deluge")                    # => :lt  (space has weight)
```

### `:shifted`

Variable characters are ignored at primary through tertiary levels.
This makes `co-op` and `coop` compare as equal:

```elixir
Cldr.Collation.compare("co-op", "coop", alternate: :shifted)   # => :eq
Cldr.Collation.compare("de luge", "deluge", alternate: :shifted) # => :eq
```

At `:quaternary` strength, shifted variable characters become distinguishable
again — the original primary weight moves to a fourth comparison level:

```elixir
Cldr.Collation.compare("co-op", "coop",
  alternate: :shifted, strength: :quaternary)                   # => :lt
```

The convenience option `:ignore_punctuation` sets `alternate: :shifted`.

---

## Max variable

The `max_variable` option controls which characters are considered
"variable" when `alternate: :shifted` is active:

| Value       | Variable characters include       |
|-------------|-----------------------------------|
| `:space`    | Whitespace only                   |
| `:punct`    | Whitespace + punctuation (default)|
| `:symbol`   | Whitespace + punctuation + symbols|
| `:currency` | All of the above + currency signs |

For example, with `max_variable: :currency`, currency symbols like `$`
and `€` are ignored at the primary level under shifted mode.

---

## Case first

The `case_first` option changes whether uppercase or lowercase sorts first
among otherwise-equal strings.

### Default (no `case_first`)

Lowercase sorts before uppercase:

```elixir
Cldr.Collation.compare("café", "Café")                        # => :lt
```

Sort order: `café` then `Café`.

### `case_first: :upper`

Uppercase sorts before lowercase:

```elixir
Cldr.Collation.compare("café", "Café", case_first: :upper)    # => :gt
```

Sort order with the full word list:

```
cafe | Café | café | co-op | naive | naïve | Résumé | résumé | TR35 | UTS10
```

Notice `Café` now precedes `café`, and `Résumé` precedes `résumé`.

### `case_first: :lower`

Explicitly marks lowercase-first (same as the default behavior):

```
cafe | café | Café | co-op | naive | naïve | résumé | Résumé | TR35 | UTS10
```

Some locales set `case_first: :upper` by default. Danish (`da`),
Norwegian Bokmål (`nb`), and Norwegian Nynorsk (`nn`) all sort
uppercase before lowercase as their locale default.

---

## Case level

The `case_level` option inserts an extra comparison level between
secondary (accents) and tertiary (case), allowing case to be
distinguished even at primary or secondary strength:

```elixir
Cldr.Collation.compare("cafe", "Cafe", strength: :primary)                    # => :eq
Cldr.Collation.compare("cafe", "Cafe", strength: :primary, case_level: true)  # => :lt
```

Without `case_level`, primary strength ignores case entirely. With
`case_level: true`, case differences are checked even though accent
differences are not.

---

## Backwards (French accent sorting)

The `backwards` option reverses the comparison direction for secondary
weights (accents). This implements the French sorting convention where
the *last* accent difference takes priority.

```elixir
# Default: leftmost accent difference wins
Cldr.Collation.compare("côte", "coté")                        # => :gt
# ô (on 2nd char) vs. é (on 4th char) — ô is encountered first, decides it

# Backwards: rightmost accent difference wins
Cldr.Collation.compare("côte", "coté", backwards: true)       # => :lt
# é (on 4th char) is the last difference — coté has the later accent
```

The full French sorting example with `cote`, `coté`, `côte`, `côté`:

| Order  | Default                        | `backwards: true`              |
|--------|--------------------------------|--------------------------------|
| 1      | cote                           | cote                           |
| 2      | coté                           | côte                           |
| 3      | côte                           | coté                           |
| 4      | côté                           | côté                           |

Notice positions 2 and 3 are swapped — with `backwards: true`, the
accent on the final vowel takes priority over the accent on the
first vowel.

---

## Numeric

The `numeric` option treats sequences of digits as numeric values
rather than comparing them character-by-character:

```elixir
# Default: "10" < "2" because "1" < "2" character-by-character
Cldr.Collation.sort(["item2", "item10", "item1"])
# => ["item1", "item10", "item2"]

# Numeric: "2" < "10" because 2 < 10 as numbers
Cldr.Collation.sort(["item2", "item10", "item1"], numeric: true)
# => ["item1", "item2", "item10"]
```

This is especially useful for version numbers and numbered labels:

```elixir
Cldr.Collation.sort(["v1.9", "v1.10", "v1.2"])
# => ["v1.10", "v1.2", "v1.9"]           (character-by-character)

Cldr.Collation.sort(["v1.9", "v1.10", "v1.2"], numeric: true)
# => ["v1.2", "v1.9", "v1.10"]           (numeric comparison)
```

---

## Reorder

The `reorder` option changes the relative ordering of scripts. By
default, the Unicode Collation Algorithm sorts Latin before Greek
before Cyrillic, etc. The `reorder` option promotes specified scripts
to sort first.

```elixir
words = ["alpha", "αλφα", "бета", "100"]

Cldr.Collation.sort(words)
# => ["100", "alpha", "αλφα", "бета"]         (default: digits, Latin, Greek, Cyrillic)

Cldr.Collation.sort(words, reorder: [:Grek])
# => ["100", "αλφα", "alpha", "бета"]         (Greek promoted before Latin)

Cldr.Collation.sort(words, reorder: [:Cyrl])
# => ["100", "бета", "alpha", "αλφα"]         (Cyrillic promoted before Latin)

Cldr.Collation.sort(words, reorder: [:Grek, :Cyrl])
# => ["100", "αλφα", "бета", "alpha"]         (Greek first, then Cyrillic, then Latin)

Cldr.Collation.sort(words, reorder: [:Cyrl, :Grek])
# => ["100", "бета", "αλφα", "alpha"]         (Cyrillic first, then Greek, then Latin)
```

The listed scripts are promoted in the order given. Unlisted scripts
retain their relative order after the promoted ones. Digits and
punctuation always sort first regardless of reorder settings.

This is useful for applications like a Greek-language phone directory
where Greek names should appear before transliterated Latin names, or
a Russian application where Cyrillic entries should sort before Latin
transliterations.

---

## Locale-specific tailoring

The `locale` option applies locale-specific sorting rules that change
the ordering of certain characters. These differences can be dramatic.

### German: dictionary vs. phonebook

German has two collation types. The default (dictionary) sorts umlauted
vowels with their base letter. The phonebook type expands them — treating
`Ä` as `AE`, `Ö` as `OE`, `Ü` as `UE`:

```elixir
words = ["Ärger", "Alter", "Ofen", "Öl", "Über", "Ulm"]

Cldr.Collation.sort(words)
# => ["Alter", "Ärger", "Ofen", "Öl", "Über", "Ulm"]

Cldr.Collation.sort(words, locale: "de-u-co-phonebk")
# => ["Ärger", "Alter", "Öl", "Ofen", "Über", "Ulm"]
```

In the default sort, `Alter` comes before `Ärger` (A before Ä is a
secondary difference). In the phonebook sort, `Ärger` sorts as if
spelled `Aerger`, placing it before `Alter`.

The practical impact is most visible with surnames — exactly the
scenario German phone directories are designed for:

```elixir
names = ["Müller", "Mueller", "Muller", "Mütze", "Much"]

Cldr.Collation.sort(names, locale: "de")
# => ["Much", "Mueller", "Muller", "Müller", "Mütze"]

Cldr.Collation.sort(names, locale: "de-u-co-phonebk")
# => ["Much", "Mueller", "Müller", "Mütze", "Muller"]
```

In dictionary order, `Müller` sorts after `Muller` — the umlaut is a
secondary variant of `u`. In phonebook order, `Müller` is treated as
`Mueller`, so it groups next to `Mueller` and before `Muller`. This
is the behavior Germans expect when looking up a name in a phone book:
someone named `Müller` should appear near `Mueller`, not separated
from it by `Muller`.

### Swedish: å ä ö sort at the end

In Swedish, the letters å, ä, ö are independent letters that sort
*after* z — not as accented variants of a and o:

```elixir
words = ["ånger", "ärlig", "zero", "öra"]

Cldr.Collation.sort(words)
# => ["ånger", "ärlig", "öra", "zero"]          (default: accented = base letter variants)

Cldr.Collation.sort(words, locale: "sv")
# => ["zero", "ånger", "ärlig", "öra"]          (Swedish: å ä ö after z)
```

### Danish: æ ø å sort at the end

Similar to Swedish, Danish treats æ, ø, å as separate letters after z:

```elixir
words = ["ånger", "ærlig", "zero", "ål", "øre"]

Cldr.Collation.sort(words)
# => ["ærlig", "ål", "ånger", "øre", "zero"]

Cldr.Collation.sort(words, locale: "da")
# => ["zero", "ærlig", "øre", "ål", "ånger"]
```

### Spanish: traditional sort with ch and ll

Traditional Spanish sorting treats `ch` and `ll` as single letters
that sort after `c` and `l` respectively:

```elixir
words = ["Chile", "chocolate", "llamar", "luna"]

Cldr.Collation.sort(words)
# => ["Chile", "chocolate", "llamar", "luna"]    (default: character-by-character)

Cldr.Collation.sort(words, locale: "es-u-co-trad")
# => ["Chile", "chocolate", "luna", "llamar"]    (traditional: ll after l)
```

In the traditional sort, `luna` precedes `llamar` because `ll` is
treated as a letter that comes after `l`.

---

## BCP47 locale strings

All options can be specified via BCP47 `-u-` extension keys in a
locale string, making it possible to express collation preferences
in a single string:

| BCP47 key | Option            | Example                       |
|-----------|-------------------|-------------------------------|
| `-ks-`    | `strength`        | `en-u-ks-level2` (secondary)  |
| `-ka-`    | `alternate`       | `en-u-ka-shifted`             |
| `-kb-`    | `backwards`       | `fr-u-kb-true`                |
| `-kc-`    | `case_level`      | `en-u-kc-true`                |
| `-kf-`    | `case_first`      | `en-u-kf-upper`               |
| `-kn-`    | `numeric`         | `en-u-kn-true`                |
| `-kr-`    | `reorder`         | `en-u-kr-grek`                |
| `-kv-`    | `max_variable`    | `en-u-kv-space`               |
| `-co-`    | collation `type`  | `de-u-co-phonebk`             |

For example:

```elixir
Cldr.Collation.sort(words, locale: "en-u-ks-level2-ka-shifted-kn-true")
```

This sorts at secondary strength, with shifted punctuation handling,
and numeric digit comparison — all expressed in a single locale string.

---

## Summary of option effects

| Option               | Controls                    | Key effect on example list                      |
|----------------------|-----------------------------|-------------------------------------------------|
| `strength: :primary` | Comparison depth            | `cafe` = `café` = `Café`                        |
| `strength: :secondary`| Comparison depth           | `cafe` ≠ `café`, but `café` = `Café`            |
| `alternate: :shifted`| Punctuation/space handling  | `co-op` = `coop`, `de luge` = `deluge`          |
| `case_first: :upper` | Case ordering               | `Café` before `café`, `Résumé` before `résumé`  |
| `case_level: true`   | Case at lower strengths     | Case distinguished even at `:primary` strength  |
| `backwards: true`    | Accent comparison direction | `côte` before `coté` (French convention)        |
| `numeric: true`      | Digit handling              | `item2` before `item10`                         |
| `max_variable`       | Shifted boundary            | Controls which symbols are ignored under shifted|
| `reorder`            | Script ordering             | `[:Grek]` promotes Greek before Latin           |
| `locale`             | Locale tailoring            | `Ärger` before `Alter` (German phonebook)       |
