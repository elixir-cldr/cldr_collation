defmodule Collation.Element do
  @moduledoc """
  A Collation Element (CE) with primary, secondary, and tertiary weights.

  Weights follow the CLDR/UCA specification:
  - Primary: base character identity (0x0000-0xFFFF)
  - Secondary: accent/diacritic differences (0x0000-0x01FF)
  - Tertiary: case/width/variant differences (0x0000-0x003F)
  """

  defstruct primary: 0, secondary: 0, tertiary: 0, variable: false

  @type t :: %__MODULE__{
          primary: non_neg_integer(),
          secondary: non_neg_integer(),
          tertiary: non_neg_integer(),
          variable: boolean()
        }

  @doc "Returns true if all weights are zero (completely ignorable)."
  def ignorable?(%__MODULE__{primary: 0, secondary: 0, tertiary: 0}), do: true
  def ignorable?(_), do: false

  @doc "Returns true if the primary weight is zero."
  def primary_ignorable?(%__MODULE__{primary: 0}), do: true
  def primary_ignorable?(_), do: false

  @doc "Returns true if this CE is a variable element (space, punct, symbol, currency)."
  def variable?(%__MODULE__{variable: true, primary: p}, _max_variable_primary) when p > 0, do: true
  def variable?(_, _), do: false
end
