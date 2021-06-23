# Changelog

## Ex_Cldr_Collation v0.5.0

This is the changelog for Cldr_collation v0.5.0 released on June 23rd, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_collation/tags)

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
