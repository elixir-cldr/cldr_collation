defmodule Cldr.Collation.DocTest do
  use ExUnit.Case, async: true

  doctest Cldr.Collation
  doctest Cldr.Collation.Element
  doctest Cldr.Collation.Han
  doctest Cldr.Collation.ImplicitWeights
  doctest Cldr.Collation.Normalizer
  doctest Cldr.Collation.Numeric
  doctest Cldr.Collation.Options
  doctest Cldr.Collation.Reorder
  doctest Cldr.Collation.SortKey
  doctest Cldr.Collation.Table
  doctest Cldr.Collation.Table.Parser
  doctest Cldr.Collation.Tailoring
  doctest Cldr.Collation.Tailoring.LocaleDefaults
  doctest Cldr.Collation.Variable
end
