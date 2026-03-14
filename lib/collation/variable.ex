defmodule Collation.Variable do
  @moduledoc """
  Variable weight handling for the collation algorithm.

  In the UCA, "variable" collation elements are those for spaces, punctuation,
  and optionally symbols and currency signs. The `alternate` setting controls
  how these are handled:

  - `:non_ignorable` - Variable CEs keep all their weights (default for CLDR)
  - `:shifted` - Variable CEs have L1/L2/L3 zeroed, original L1 moves to L4
  """

  alias Collation.Element

  @doc """
  Process a list of collation elements according to the variable weight rules.

  ### Arguments

  * `elements` - a list of `%Collation.Element{}` structs
  * `alternate` - the variable handling mode: `:non_ignorable` or `:shifted`
  * `max_variable_primary` - the maximum primary weight for variable elements

  ### Returns

  A list of `{%Collation.Element{}, quaternary_weight}` tuples.

  For `:non_ignorable`, quaternary is always `0`.
  For `:shifted`:
  - Variable CEs: L1/L2/L3 become 0, L4 = original L1
  - Ignorable CEs following a variable: all weights become 0, L4 = 0
  - Regular CEs with primary > 0: L4 = `0xFFFF`
  - Primary-ignorable CEs not after a variable: L4 = `0`

  ### Examples

      iex> elems = [%Collation.Element{primary: 0x23EC, secondary: 0x0020, tertiary: 0x0002}]
      iex> [{elem, q}] = Collation.Variable.process(elems, :non_ignorable, 0x0B61)
      iex> {elem.primary, q}
      {0x23EC, 0}
  """
  def process(elements, :non_ignorable, _max_variable_primary) do
    Enum.map(elements, fn elem -> {elem, 0} end)
  end

  def process(elements, :shifted, max_variable_primary) do
    {result, _after_variable} =
      Enum.reduce(elements, {[], false}, fn elem, {acc, after_variable} ->
        cond do
          # Variable element: zero out L1/L2/L3, set L4 to original L1
          Element.variable?(elem, max_variable_primary) ->
            shifted = %Element{primary: 0, secondary: 0, tertiary: 0}
            {[{shifted, elem.primary} | acc], true}

          # Ignorable CE after variable: zero all weights, L4 = 0
          after_variable and Element.primary_ignorable?(elem) ->
            zeroed = %Element{primary: 0, secondary: 0, tertiary: 0}
            {[{zeroed, 0} | acc], true}

          # Regular CE: L4 = 0xFFFF if primary > 0, else L4 = 0
          true ->
            l4 = if elem.primary > 0, do: 0xFFFF, else: 0
            {[{elem, l4} | acc], false}
        end
      end)

    Enum.reverse(result)
  end
end
