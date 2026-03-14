defmodule Collation.SortKey do
  @moduledoc """
  Constructs binary sort keys from processed collation elements.

  Sort keys are multi-level byte sequences that can be compared with
  binary comparison (`<`, `>`, `==`) to determine string ordering.

  Structure: [L1 weights] 0000 [L2 weights] 0000 [L3 weights] [0000 L4 weights]
  """

  import Bitwise

  alias Collation.Options

  @level_separator <<0x00, 0x00>>

  @doc """
  Build a binary sort key from processed elements.

  `processed_elements` is a list of `{%Element{}, quaternary}` tuples
  as returned by `Variable.process/3`.
  """
  def build(processed_elements, %Options{} = opts, original_string \\ nil) do
    key = build_primary(processed_elements)

    key =
      if opts.strength in [:secondary, :tertiary, :quaternary, :identical] do
        key <> @level_separator <> build_secondary(processed_elements, opts)
      else
        key
      end

    key =
      if opts.strength in [:tertiary, :quaternary, :identical] do
        # Insert case level between L2 and L3 if case_level is on
        key =
          if opts.case_level do
            key <> @level_separator <> build_case_level(processed_elements)
          else
            key
          end

        key <> @level_separator <> build_tertiary(processed_elements, opts)
      else
        # If case_level is on with strength=secondary, add case level after L2
        if opts.case_level do
          key <> @level_separator <> build_case_level(processed_elements)
        else
          key
        end
      end

    key =
      if opts.strength in [:quaternary, :identical] and opts.alternate == :shifted do
        key <> @level_separator <> build_quaternary(processed_elements)
      else
        key
      end

    key =
      if opts.strength == :identical do
        # Identical level: append NFD of original string
        nfd = if original_string, do: :unicode.characters_to_nfd_binary(original_string), else: <<>>
        key <> @level_separator <> nfd
      else
        key
      end

    key
  end

  defp build_primary(elements) do
    elements
    |> Enum.reduce(<<>>, fn {elem, _q}, acc ->
      if elem.primary > 0 do
        acc <> <<elem.primary::16>>
      else
        acc
      end
    end)
  end

  defp build_secondary(elements, opts) do
    weights =
      elements
      |> Enum.reduce([], fn {elem, _q}, acc ->
        if elem.secondary > 0 do
          [elem.secondary | acc]
        else
          acc
        end
      end)
      |> Enum.reverse()

    weights =
      if opts.backwards do
        Enum.reverse(weights)
      else
        weights
      end

    weights
    |> Enum.reduce(<<>>, fn w, acc -> acc <> <<w::16>> end)
  end

  defp build_tertiary(elements, opts) do
    elements
    |> Enum.reduce(<<>>, fn {elem, _q}, acc ->
      t = apply_case_first(elem.tertiary, opts.case_first)

      if t > 0 do
        acc <> <<t::16>>
      else
        acc
      end
    end)
  end

  defp build_case_level(elements) do
    # Case level extracts case information from tertiary weights
    # Upper case = tertiary & 0x08 (bit 3 set)
    elements
    |> Enum.reduce(<<>>, fn {elem, _q}, acc ->
      if elem.primary > 0 do
        case_bit = if (elem.tertiary &&& 0x08) != 0, do: 1, else: 0
        acc <> <<case_bit::16>>
      else
        acc
      end
    end)
  end

  defp build_quaternary(elements) do
    elements
    |> Enum.reduce(<<>>, fn {_elem, q}, acc ->
      if q > 0 do
        acc <> <<q::16>>
      else
        acc
      end
    end)
  end

  defp apply_case_first(tertiary, false), do: tertiary

  defp apply_case_first(tertiary, :upper) do
    # Invert case bit so upper sorts before lower
    case_bit = tertiary &&& 0x08

    if case_bit != 0 do
      # Upper case: make it sort first by clearing the bit
      tertiary &&& Bitwise.bnot(0x08)
    else
      # Lower case: make it sort after by setting the bit
      tertiary ||| 0x08
    end
  end

  defp apply_case_first(tertiary, :lower) do
    # Lower case sorts first (default tertiary behavior is lower-first)
    tertiary
  end
end
