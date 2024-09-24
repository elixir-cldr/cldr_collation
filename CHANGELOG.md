# Changelog

## Ex_Cldr_Collation v0.7.4

This is the changelog for Cldr_collation v0.7.4 released on September 25th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_collation/tags)

### Bug fixes

* Fix Makefile for Darwin (MacOS) when running in [devenv](https://devenv.sh)

## Ex_Cldr_Collation v0.7.3

This is the changelog for Cldr_collation v0.7.3 released on May 28th, 2024.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_collation/tags)

### Bug fixes

* Fix compiler warnings for Elixir 1.17.

## Ex_Cldr_Collation v0.7.2

This is the changelog for Cldr_collation v0.7.2 released on February 8th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_collation/tags)

### Bug fixes

* Makes the `Makefile` more resilient by exiting if `pkg-config` isn't installed and therefore `ICU_LIBS` is empty. Previously this would fail silently and an unclear runtime error would be reported.

* Improved the error message if the NIF can't be loaded. Thanks to @linusdm.  Closes #8.

## Ex_Cldr_Collation v0.7.1

This is the changelog for Cldr_collation v0.7.1 released on February 24th, 2023.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_collation/tags)

### Bug fixes

* Add binary guards to `Cldr.Collation.compare/3`.

## Ex_Cldr_Collation v0.7.0

This is the changelog for Cldr_collation v0.7.0 released on January 4th, 2022.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_collation/tags)

### Bug fixes

* Fix the .so path for the NIF at load time, not compile time. Thanks to @sergiorjsd for the report. Closes #3.

* Fix buidling on ARM-based Mac models

## Ex_Cldr_Collation v0.6.0

This is the changelog for Cldr_collation v0.6.0 released on July 3rd, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_collation/tags)

### Bug fixes

* Load the nif from a path relative to `:code.priv_dir/1`.

## Ex_Cldr_Collation v0.5.0

This is the changelog for Cldr_collation v0.5.0 released on June 23rd, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_collation/tags)

### Bug fixes

* Correctly reference the `ucol.so` file when loading at startup

* Removes unrequired dependencies

### Enhancements

* Adds `Cldr.Collator.sort/2`

* Adds documentation for `Cldr.Collator.compare/3`

## Ex_Cldr_Collation v0.4.0

This is the changelog for Cldr_collation v0.4.0 released on April 9th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_collation/tags)

### Bug Fixes

* Fix compilation issues on OTP 23 and later. On these releases, `liberl_interface.a` doesn't exist and isn't required.  Thanks to @zookzook for the report.

## Ex_Cldr_Collation v0.3.0

This is the changelog for Cldr_collation v0.3.0 released on March 3rd, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_collation/tags)

### Enhancements

* Add `:inets` to `:extra_applications` for later versions of Elixir

* Fix application name in `README.md`. Thanks to @phlppn.

* Note the requirement for Elixir 1.10 or later in order to use the module-based comparators for `Enum.sort/2`.

## Ex_Cldr_Collation v0.2.0

This is the changelog for Cldr_collation v0.2.0 released on Match 13th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_collation/tags)

### Enhancements

* Adds support for module-based comparators used by `Enum.sort/2` on Elixir 1.10 and later. The comparitor modules are `Cldr.Collator` (which is case insensitive), `Cldr.Collator.Sensitive` (case sensitive comparison) and `Cldr.Collator.Insensitive` (case insensitive comparison).
