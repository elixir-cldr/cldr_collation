# Cldr Collation

A NIF-based Unicode collator based upon the Unicode library `libicu4c`. Builds upon the
erland library [erlang-ucol](https://github.com/barrel-db/erlang-ucol) by BenoÃ®t Chesneau <benoitc@e-engura.org>
and Nicolas Dufour <nrdufour@gmail.com>

## Requirements

This module requires the package `icu4c` be installed on your system.

For OSX users, the standard installation that is deliviered with MAC OS is used. Not separate installation is required.

## Installation

The package can be installed by adding `cldr_collation` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cldr_collation, "~> 0.1.0"}
  ]
end
```


