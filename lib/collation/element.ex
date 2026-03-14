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

  @doc """
  Check if a collation element is completely ignorable.

  A completely ignorable element has all weights (primary, secondary, tertiary)
  set to zero.

  ### Arguments

  * `element` - a `%Collation.Element{}` struct

  ### Returns

  * `true` if all weights are zero
  * `false` otherwise

  ### Examples

      iex> Collation.Element.ignorable?(%Collation.Element{primary: 0, secondary: 0, tertiary: 0})
      true

      iex> Collation.Element.ignorable?(%Collation.Element{primary: 0, secondary: 0x0020, tertiary: 0})
      false
  """
  def ignorable?(%__MODULE__{primary: 0, secondary: 0, tertiary: 0}), do: true
  def ignorable?(_), do: false

  @doc """
  Check if a collation element is primary-ignorable.

  A primary-ignorable element has a primary weight of zero but may have
  non-zero secondary or tertiary weights (e.g., combining accents).

  ### Arguments

  * `element` - a `%Collation.Element{}` struct

  ### Returns

  * `true` if the primary weight is zero
  * `false` otherwise

  ### Examples

      iex> Collation.Element.primary_ignorable?(%Collation.Element{primary: 0, secondary: 0x0024, tertiary: 0x0002})
      true

      iex> Collation.Element.primary_ignorable?(%Collation.Element{primary: 0x23EC, secondary: 0x0020, tertiary: 0x0002})
      false
  """
  def primary_ignorable?(%__MODULE__{primary: 0}), do: true
  def primary_ignorable?(_), do: false

  @doc """
  Check if a collation element is a variable element.

  Variable elements represent spaces, punctuation, symbols, and currency signs.
  They are identified by the `variable: true` flag set during parsing of the
  allkeys table (marked with `*` prefix in the data file).

  ### Arguments

  * `element` - a `%Collation.Element{}` struct
  * `max_variable_primary` - the maximum primary weight for variable elements (unused, retained for API compatibility)

  ### Returns

  * `true` if the element is marked as variable and has a non-zero primary weight
  * `false` otherwise

  ### Examples

      iex> Collation.Element.variable?(%Collation.Element{primary: 0x0269, variable: true}, 0x0B61)
      true

      iex> Collation.Element.variable?(%Collation.Element{primary: 0x23EC, variable: false}, 0x0B61)
      false
  """
  def variable?(%__MODULE__{variable: true, primary: p}, _max_variable_primary) when p > 0,
    do: true

  def variable?(_, _), do: false
end
