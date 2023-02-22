# Cldr Collation

A NIF-based Unicode collator based upon the Unicode library `libicu4c`. Builds upon the
erlang library [erlang-ucol](https://github.com/barrel-db/erlang-ucol) by Benoit Chesneau <benoitc@e-engura.org> and Nicolas Dufour <nrdufour@gmail.com>

This initial version uses only the "root" locale collator which is the [CLDR DUCET collator](http://userguide.icu-project.org/collation).


## Installation

### Installing libicu

`ex_cldr_collation` relies upon [libicu](https://icu.unicode.org) which must be installed prior to configuration and compiling this library.  Depending on your platform, `icu-dev` may also need to be installed.

### Installation on MacOS

On MacOS, the relevant headers are included in `ex_cldr_collation` and no additional installation is required.

### Installation on Linux

On Linux systems, `libicu-dev`, `libicu` and `pckconf` must be installed and well as basic development tools for the build process.

```bash
# For Ubuntu
# libicu is required for compiling the NIF
# assumes libicu is already installed which is normal on Ubuntu
$ sudo apt-get install pkgconf libicu-dev

# For Alpine
# icu-dev is required when compiling the NIF
# icu is required at runtime
$ apk add pkgconf icu-dev icu

# Then check that we can resolve the libicu package
# dependencies
$ pkg-config --libs icu-uc icu-io
-licuio -licui18n -licuuc -licudata
```

### Installing ex_cldr_collation
The package can then be installed by adding `cldr_collation` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_cldr_collation, "~> 0.7.0"}
  ]
end
```

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





