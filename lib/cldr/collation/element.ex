defmodule Cldr.Collation.Element do
  @moduledoc """
  A Cldr.Collation Element (CE) with primary, secondary, and tertiary weights.

  Elements are represented as `{primary, secondary, tertiary, variable}` tuples
  for compact persistent_term storage. Constructor and accessor functions provide
  a readable interface.

  Weights follow the CLDR/UCA specification:
  - Primary: base character identity (0x0000-0xFFFF)
  - Secondary: accent/diacritic differences (0x0000-0x01FF)
  - Tertiary: case/width/variant differences (0x0000-0x003F)

  """

  @type t :: {non_neg_integer(), non_neg_integer(), non_neg_integer(), boolean()}

  @doc """
  Create a new collation element tuple.

  ### Arguments

  * `primary` - the primary weight (default: `0`).
  * `secondary` - the secondary weight (default: `0`).
  * `tertiary` - the tertiary weight (default: `0`).
  * `variable` - whether this is a variable element (default: `false`).

  ### Returns

  A `{primary, secondary, tertiary, variable}` tuple.

  ### Examples

      iex> Cldr.Collation.Element.new(0x23EC, 0x0020, 0x0008, false)
      {0x23EC, 0x0020, 0x0008, false}

  """
  def new(primary \\ 0, secondary \\ 0, tertiary \\ 0, variable \\ false) do
    {primary, secondary, tertiary, variable}
  end

  @doc """
  Get the primary weight of a collation element.

  ### Arguments

  * `element` - a collation element tuple.

  ### Returns

  The primary weight as a non-negative integer.

  ### Examples

      iex> Cldr.Collation.Element.primary({0x23EC, 0x0020, 0x0008, false})
      0x23EC

  """
  def primary({p, _, _, _}), do: p

  @doc """
  Get the secondary weight of a collation element.

  ### Arguments

  * `element` - a collation element tuple.

  ### Returns

  The secondary weight as a non-negative integer.

  ### Examples

      iex> Cldr.Collation.Element.secondary({0x23EC, 0x0020, 0x0008, false})
      0x0020

  """
  def secondary({_, s, _, _}), do: s

  @doc """
  Get the tertiary weight of a collation element.

  ### Arguments

  * `element` - a collation element tuple.

  ### Returns

  The tertiary weight as a non-negative integer.

  ### Examples

      iex> Cldr.Collation.Element.tertiary({0x23EC, 0x0020, 0x0008, false})
      0x0008

  """
  def tertiary({_, _, t, _}), do: t

  @doc """
  Check if a collation element is completely ignorable.

  A completely ignorable element has all weights (primary, secondary, tertiary)
  set to zero.

  ### Arguments

  * `element` - a collation element tuple.

  ### Returns

  * `true` if all weights are zero.
  * `false` otherwise.

  ### Examples

      iex> Cldr.Collation.Element.ignorable?({0, 0, 0, false})
      true

      iex> Cldr.Collation.Element.ignorable?({0, 0x0020, 0, false})
      false

  """
  def ignorable?({0, 0, 0, _}), do: true
  def ignorable?(_), do: false

  @doc """
  Check if a collation element is primary-ignorable.

  A primary-ignorable element has a primary weight of zero but may have
  non-zero secondary or tertiary weights (e.g., combining accents).

  ### Arguments

  * `element` - a collation element tuple.

  ### Returns

  * `true` if the primary weight is zero.
  * `false` otherwise.

  ### Examples

      iex> Cldr.Collation.Element.primary_ignorable?({0, 0x0024, 0x0002, false})
      true

      iex> Cldr.Collation.Element.primary_ignorable?({0x23EC, 0x0020, 0x0002, false})
      false

  """
  def primary_ignorable?({0, _, _, _}), do: true
  def primary_ignorable?(_), do: false

  @doc """
  Check if a collation element is a variable element.

  Variable elements represent spaces, punctuation, symbols, and currency signs.
  They are identified by the `variable: true` flag set during parsing of the
  collation table (derived from the `[first variable]` and `[last variable]`
  boundaries in FractionalUCA.txt).

  ### Arguments

  * `element` - a collation element tuple.
  * `max_variable_primary` - the maximum primary weight for variable elements (unused, retained for API compatibility).

  ### Returns

  * `true` if the element is marked as variable and has a non-zero primary weight.
  * `false` otherwise.

  ### Examples

      iex> Cldr.Collation.Element.variable?({0x0269, 0x0020, 0x0002, true}, 0x0B61)
      true

      iex> Cldr.Collation.Element.variable?({0x23EC, 0x0020, 0x0002, false}, 0x0B61)
      false

  """
  def variable?({p, _, _, true}, _max_variable_primary) when p > 0, do: true
  def variable?(_, _), do: false
end
