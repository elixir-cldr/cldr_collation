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

  Returns a list of `{%Element{}, quaternary_weight}` tuples.

  For `:non_ignorable`, quaternary is always 0.
  For `:shifted`:
  - Variable CEs: L1/L2/L3 become 0, L4 = original L1
  - Ignorable CEs following a variable: L4 = 0 (already ignorable)
  - Regular CEs: L4 = 0xFFFF (maximum, sorts after shifted)
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

          # Regular CE (including primary-ignorable not after variable): L4 = 0xFFFF
          true ->
            {[{elem, 0xFFFF} | acc], false}
        end
      end)

    Enum.reverse(result)
  end
end
