# Cldr Collation

A NIF-based Unicode collator based upon the Unicode library `libicu4c`. Builds upon the
erlang library [erlang-ucol](https://github.com/barrel-db/erlang-ucol) by BenoÃ®t Chesneau <benoitc@e-engura.org> and Nicolas Dufour <nrdufour@gmail.com>

This initial version uses only the "root" locale collator which is the [CLDR DUCET collator](http://userguide.icu-project.org/collation).

## Requirements

This module requires the package `icu4c` be installed on your system.

For Mac OS users, the standard installation that is delivered with Mac OS is used. No separate installation is required.

## Examples
```elixir
  # Sorting using Cldr.Collator.sort/2
  iex> Cldr.Collation.sort(["á", "b", "A"], casing: :sensitive)
  ["A", "á", "b"]

  iex> Cldr.Collation.sort(["á", "b", "A"], casing: :insensitive)
  ["á", "A", "b"]

  # Comparing strings
  iex> Cldr.Collation.compare("a", "A", casing: :insensitive)
  :eq

  iex> Cldr.Collation.compare("a", "A", casing: :sensitive)
  :lt

  # Using Elixir 1.10 Enum.sort
  # Cldr.Collation.Sensitive, Cldr.Collation.Insensitive
  # comparise modules are provided

  iex> Enum.sort(["AAAA", "AAAa"], Cldr.Collation.Insensitive)
  ["AAAA", "AAAa"]

  iex> Enum.sort(["AAAA", "AAAa"], Cldr.Collation.Sensitive)
  ["AAAa", "AAAA"]
```

## Installation

The package can be installed by adding `cldr_collation` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_cldr_collation, "~> 0.5.0"}
  ]
end
```

Ensure the package `icu4c` is installed on your system before invoking `mix compile` or `iex -S mix`.



