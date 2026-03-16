defmodule Cldr.Collation.Variable do
  @moduledoc """
  Variable weight handling for the collation algorithm.

  In the UCA, "variable" collation elements are those for spaces, punctuation,
  and optionally symbols and currency signs. The `alternate` setting controls
  how these are handled:

  * `:non_ignorable` - Variable CEs keep all their weights (default for CLDR).

  * `:shifted` - Variable CEs have L1/L2/L3 zeroed, original L1 moves to L4.

  """

  alias Cldr.Collation.Element

  @doc """
  Process a list of collation elements according to the variable weight rules.

  ### Arguments

  * `elements` - a list of collation element tuples.
  * `alternate` - the variable handling mode: `:non_ignorable` or `:shifted`.
  * `max_variable_primary` - the maximum primary weight for variable elements.

  ### Returns

  A list of `{element, quaternary_weight}` tuples.

  For `:non_ignorable`, quaternary is always `0`.
  For `:shifted`:

  * Variable CEs: L1/L2/L3 become 0, L4 = original L1.

  * Ignorable CEs following a variable: all weights become 0, L4 = 0.

  * Regular CEs with primary > 0: L4 = `0xFFFF`.

  * Primary-ignorable CEs not after a variable: L4 = `0`.

  ### Examples

      iex> elems = [{0x23EC, 0x0020, 0x0002, false}]
      iex> [{elem, q}] = Cldr.Collation.Variable.process(elems, :non_ignorable, 0x0B61)
      iex> {Cldr.Collation.Element.primary(elem), q}
      {0x23EC, 0}

  """
  @spec process([Element.t()], :non_ignorable | :shifted, non_neg_integer()) ::
          [{Element.t(), non_neg_integer()}]
  def process(elements, :non_ignorable, _max_variable_primary) do
    Enum.map(elements, fn elem -> {elem, 0} end)
  end

  def process(elements, :shifted, max_variable_primary) do
    {result, _after_variable} =
      Enum.reduce(elements, {[], false}, fn elem, {acc, after_variable} ->
        cond do
          # Variable element: zero out L1/L2/L3, set L4 to original L1
          Element.variable?(elem, max_variable_primary) ->
            shifted = Element.new(0, 0, 0)
            {[{shifted, Element.primary(elem)} | acc], true}

          # Ignorable CE after variable: zero all weights, L4 = 0
          after_variable and Element.primary_ignorable?(elem) ->
            zeroed = Element.new(0, 0, 0)
            {[{zeroed, 0} | acc], true}

          # Regular CE: L4 = 0xFFFF if primary > 0, else L4 = 0
          true ->
            l4 = if Element.primary(elem) > 0, do: 0xFFFF, else: 0
            {[{elem, l4} | acc], false}
        end
      end)

    Enum.reverse(result)
  end
end
