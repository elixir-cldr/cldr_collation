defmodule Cldr.Collation.SortKey do
  @moduledoc """
  Constructs binary sort keys from processed collation elements.

  Sort keys are multi-level byte sequences that can be compared with
  binary comparison (`<`, `>`, `==`) to determine string ordering.

  Structure: [L1 weights] 0000 [L2 weights] 0000 [L3 weights] [0000 L4 weights]

  """

  import Bitwise

  alias Cldr.Collation.Options

  @level_separator <<0x00, 0x00>>

  @doc """
  Build a binary sort key from processed collation elements.

  Constructs a multi-level binary key by extracting weights at each level
  (primary, secondary, tertiary, quaternary, identical) separated by `0x0000`.

  ### Arguments

  * `processed_elements` - a list of `{%Cldr.Collation.Element{}, quaternary}` tuples as returned by `Cldr.Collation.Variable.process/3`
  * `options` - a `%Cldr.Collation.Options{}` struct controlling which levels to include
  * `original_string` - the original input string, used for the identical level (default: `nil`)

  ### Returns

  A binary sort key where levels are separated by `<<0x00, 0x00>>`. The number
  of levels included depends on the `:strength` option.

  ### Examples

      iex> elements = [{%Cldr.Collation.Element{primary: 0x23EC, secondary: 0x0020, tertiary: 0x0008}, 0}]
      iex> options = Cldr.Collation.Options.new(strength: :primary)
      iex> Cldr.Collation.SortKey.build(elements, options)
      <<0x23, 0xEC>>

  """
  def build(processed_elements, %Options{} = options, original_string \\ nil) do
    key = build_primary(processed_elements)

    key =
      if options.strength in [:secondary, :tertiary, :quaternary, :identical] do
        key <> @level_separator <> build_secondary(processed_elements, options)
      else
        key
      end

    key =
      if options.strength in [:tertiary, :quaternary, :identical] do
        # Insert case level between L2 and L3 if case_level is on
        key =
          if options.case_level do
            key <> @level_separator <> build_case_level(processed_elements)
          else
            key
          end

        key <> @level_separator <> build_tertiary(processed_elements, options)
      else
        # If case_level is on with strength=secondary, add case level after L2
        if options.case_level do
          key <> @level_separator <> build_case_level(processed_elements)
        else
          key
        end
      end

    key =
      if options.strength in [:quaternary, :identical] and options.alternate == :shifted do
        key <> @level_separator <> build_quaternary(processed_elements)
      else
        key
      end

    key =
      if options.strength == :identical do
        # Identical level: append NFD of original string
        nfd =
          if original_string, do: :unicode.characters_to_nfd_binary(original_string), else: <<>>

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

  defp build_secondary(elements, options) do
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
      if options.backwards do
        Enum.reverse(weights)
      else
        weights
      end

    weights
    |> Enum.reduce(<<>>, fn w, acc -> acc <> <<w::16>> end)
  end

  defp build_tertiary(elements, options) do
    elements
    |> Enum.reduce(<<>>, fn {elem, _q}, acc ->
      t = apply_case_first(elem.tertiary, options.case_first)

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
