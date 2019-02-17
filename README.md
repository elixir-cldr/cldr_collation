# Cldr Collation

A NIF-based Unicode collator based upon the Unicode library `libicu4c`. Builds upon the
erlang library [erlang-ucol](https://github.com/barrel-db/erlang-ucol) by BenoÃ®t Chesneau <benoitc@e-engura.org>
and Nicolas Dufour <nrdufour@gmail.com>

This initial version uses only the "root" locale collator which is the [CLDR DUCET collator](http://userguide.icu-project.org/collation).

## Requirements

This module requires the package `icu4c` be installed on your system.

For OSX users, the standard installation that is delivered with MAC OS is used. Not separate installation is required.

## Examples
```
iex> Cldr.Collation.compare("a", "A", casing: :insensitive)
:eq

iex> Cldr.Collation.compare("a", "A", casing: :sensitive)
:lt
```

## Installation

The package can be installed by adding `cldr_collation` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cldr_collation, "~> 0.1.0"}
  ]
end
```


