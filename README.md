# Cldr Collation

A NIF-based Unicode collator based upon the Unicode library `libicu4c`. Builds upon the
erlang library [erlang-ucol](https://github.com/barrel-db/erlang-ucol) by Benoit Chesneau <benoitc@e-engura.org> and Nicolas Dufour <nrdufour@gmail.com>

This initial version uses only the "root" locale collator which is the [CLDR DUCET collator](http://userguide.icu-project.org/collation).

## Installation

`ex_cldr_collation` depends upon [libicu](https://unicode-org.github.io/icu/userguide/icu/) to provide the underlying collator. There are two required components:

* At *build* time (compilation), the `libicu` development headers are are required. On MacOS these headers are provided as part of the library. For Linux systems the package typically called `libicu-dev` is required.

* At *runtime* the `libicu` library is required. On MacOS and Ubuntu this library is delivered as part of the OS. For Alpine and Debian the `icu` package needs to be installed.

### Installation on MacOS

On MacOS, the relevant headers are included in `ex_cldr_collation` and no additional installation is required.

### Installation on Linux

On Linux systems, `libicu-dev`, `libicu` and `pkg-conf` must be installed and well as basic development tools for the build process.

```bash
# For Ubuntu
# pkg-config and libicu are required for compiling the NIF
# assumes libicu is already installed which is normal on Ubuntu
$ sudo apt-get install pkgconf libicu-dev

# For Debian
# pkg-config and icu-dev are required when compiling the NIF
# libicu is required at runtime
# Debian Bullseye
$ sudo apt install pkgconf libicu-dev libicu67
# Debian Bookworm
$ sudo apt install pkgconf libicu-dev libicu72

# For Alpine
# pkg-config and icu-dev are required when compiling the NIF
# icu is required at runtime
$ apk add pkgconf icu-dev icu

# Then check that the libicu package dependencies
# can be resolved
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





