# Changelog for Cldr_Collation v0.2.0

This is the changelog for Cldr_collation v0.2.0 released on Match 13th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-cldr/cldr_units/tags)

### Enhancements

* Adds support for module-based comparators used by `Enum.sort/2` on Elixir 1.10 and later. The comparitor modules are `Cldr.Collator` (which is case insensitive), `Cldr.Collator.Sensitive` (case sensitive comparison) and `Cldr.Collator.Insensitive` (case insensitive comparison).
