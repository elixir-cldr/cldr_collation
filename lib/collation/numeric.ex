defmodule Collation.Numeric do
  @moduledoc """
  Numeric collation support (kn=true / numeric=true).

  When enabled, sequences of decimal digits are treated as numeric values
  for primary sorting, ensuring "file2" sorts before "file10".

  The numeric value is encoded as a length-prefixed big-endian number
  in the primary weight.

  """

  alias Collation.Element

  @doc """
  Process codepoint/element pairs, replacing digit sequence CEs with
  numeric-value-based CEs.

  Groups consecutive decimal digit codepoints into runs and replaces their
  collation elements with length-prefixed numeric encodings so that `"2"`
  sorts before `"10"`.

  ### Arguments

  * `ce_pairs` - a list of `{codepoints, [%Collation.Element{}]}` pairs

  ### Returns

  A flat list of `%Collation.Element{}` structs with digit sequences replaced
  by numeric collation elements.

  ### Examples

      iex> pairs = [{[0x31], [%Collation.Element{primary: 0x21E7}]}, {[0x30], [%Collation.Element{primary: 0x21E6}]}]
      iex> result = Collation.Numeric.process_elements(pairs)
      iex> length(result)
      3

  """
  def process_elements(ce_pairs) do
    ce_pairs
    |> group_digit_runs()
    |> Enum.flat_map(fn
      {:digits, codepoints} ->
        encode_numeric_value(codepoints)

      {:other, elements} ->
        elements
    end)
  end

  defp group_digit_runs(ce_pairs) do
    {groups, current} =
      Enum.reduce(ce_pairs, {[], nil}, fn {cps, elements}, {groups, current} ->
        if digit_codepoints?(cps) do
          case current do
            {:digits, acc_cps} ->
              {groups, {:digits, acc_cps ++ cps}}

            nil ->
              {groups, {:digits, cps}}

            other ->
              {[other | groups], {:digits, cps}}
          end
        else
          case current do
            nil ->
              {groups, {:other, elements}}

            {:other, acc_elems} ->
              {groups, {:other, acc_elems ++ elements}}

            digit_group ->
              {[digit_group | groups], {:other, elements}}
          end
        end
      end)

    result = if current, do: [current | groups], else: groups
    Enum.reverse(result)
  end

  defp digit_codepoints?(cps) do
    Enum.all?(cps, fn cp ->
      # ASCII digits
      # Any decimal digit
      (cp >= 0x0030 and cp <= 0x0039) or
        Unicode.GeneralCategory.category(cp) == :Nd
    end)
  end

  @doc """
  Encode a sequence of digit codepoints as numeric collation elements.

  Follows ICU's approach: converts digits to numeric values, strips leading
  zeros, then encodes as a length prefix CE followed by one CE per digit.

  ### Arguments

  * `codepoints` - a list of integer codepoints representing decimal digits

  ### Returns

  A list of `%Collation.Element{}` structs: one length-prefix CE followed by
  one CE per significant digit.

  ### Examples

      iex> result = Collation.Numeric.encode_numeric_value([0x31, 0x30])
      iex> length(result)
      3

  """
  def encode_numeric_value(codepoints) do
    # Convert to decimal digit values
    digits =
      Enum.map(codepoints, fn cp ->
        cond do
          cp >= 0x0030 and cp <= 0x0039 -> cp - 0x0030
          true -> numeric_digit_value(cp)
        end
      end)

    # Strip leading zeros (but keep at least one)
    digits = strip_leading_zeros(digits)

    # Encode length and digits into primary weights
    # Length is encoded first, then each digit
    len = length(digits)

    # Primary weight for numeric: digit base + encoded value
    # We use a scheme where the length prefix ensures longer numbers sort after shorter
    # The digit_base comes from the DIGIT group in FractionalUCA
    # Primary weight of DIGIT ZERO in allkeys_CLDR.txt
    digit_base = 0x21E6

    length_ce = %Element{
      primary: digit_base + len,
      secondary: 0x0020,
      tertiary: 0x0002
    }

    digit_ces =
      Enum.map(digits, fn d ->
        %Element{
          primary: digit_base + d,
          secondary: 0x0020,
          tertiary: 0x0002
        }
      end)

    [length_ce | digit_ces]
  end

  defp strip_leading_zeros([0]), do: [0]
  defp strip_leading_zeros([0 | rest]), do: strip_leading_zeros(rest)
  defp strip_leading_zeros(digits), do: digits

  # Compute digit value for non-ASCII decimal digits
  # Decimal digit characters in Unicode have values 0-9 within their respective blocks
  defp numeric_digit_value(cp) when cp >= 0x0030 and cp <= 0x0039, do: cp - 0x0030

  defp numeric_digit_value(cp) do
    # Unicode decimal digits are arranged in blocks of 10
    # The digit value is the offset within the block
    rem(cp, 10)
  end
end
