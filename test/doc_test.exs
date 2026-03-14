defmodule Collation.DocTest do
  use ExUnit.Case, async: true

  doctest Collation
  doctest Collation.Element
  doctest Collation.Han
  doctest Collation.ImplicitWeights
  doctest Collation.Normalizer
  doctest Collation.Numeric
  doctest Collation.Options
  doctest Collation.Reorder
  doctest Collation.SortKey
  doctest Collation.Table
  doctest Collation.Table.Parser
  doctest Collation.Tailoring
  doctest Collation.Tailoring.LocaleDefaults
  doctest Collation.Variable
end
