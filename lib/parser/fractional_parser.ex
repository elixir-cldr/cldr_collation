defmodule Cldr.Collation.Parser.Fractional do
  @uca_file "data/uca/FractionalUCA_SHORT.txt"

  def parse(file \\ @uca_file) do
    file
    |> File.stream!([:read, :utf8])
    |> Stream.map(&parse_line/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce([], &reduce_uca/2)
    # |> Map.new()
  end

  def parse_line("#" <> _rest), do: nil
  def parse_line("\n"), do: nil

  def parse_line("[" <> rest) do
    rest
    |> String.split([" ", "\t"], parts: 2)
    |> parse_meta()
  end

  def parse_line(element) do
    element
    |> String.split(["; ", ";\t", " #", "\t#"])
    |> Enum.take(2)
    |> parse_element()
  end

  def reduce_uca(element, acc) do
    [element | acc]
  end

  # [UCA version = 14.0.0]
  def parse_meta(["UCA" , rest]) do
    [_, version, _] = String.split(rest, [" = ", "]"])
    {:version, Version.parse!(version)}
  end

  # [Unified_Ideograph 4E00..9FFF FA0E..FA0F FA11
  def parse_meta(["Unified_Ideograph", _rest]) do
    nil
  end

  # [radical end]
  def parse_meta(["radical", "end]\n"]) do
    nil
  end

  #[radical 1=⼀一:一𪛙丁-丆𠀀-𠀂𬺰𰀀万-丌亐卄𠀃-𠀆𪛚𪜀𪜁𫝀𬺱-𬺴𰀁- .... ]
  def parse_meta(["radical", rest]) do
    [seq, _exemplars, characters, _end] = String.split(rest, ["=", ":", "]"])
    graphemes = String.graphemes(characters)
    {:radical, {String.trim(seq), graphemes}}
  end

  # [top_byte	00	TERMINATOR ]
  def parse_meta(["top_byte", _rest]) do
    nil
  end

  # [first tertiary ignorable [,,]] # CONSTRUCTED
  def parse_meta(["first", rest]) do
    [first, element, _, _end] = String.split(rest, ["[", "]"])
    {:first, {String.trim(first), parse_element("[" <> element)}}
  end

  # [last tertiary ignorable [,,]] # CONSTRUCTED
  def parse_meta(["last", rest]) do
    [last, element, _, _end] = String.split(rest, ["[", "]"])
    {:last, {String.trim(last), parse_element("[" <> element)}}
  end

  # [variable top = 0B FF FF FF]
  def parse_meta(["variable", rest]) do
    [top, bytes, _end] = String.split(rest, [" = ", "]"])
    {:variable, {top, to_binary(bytes)}}
  end

  # [reorderingTokens	Adlm	78=69 ]
  def parse_meta(["reorderingTokens", _rest]) do
    nil
  end

  # [categories	Cc	03{SPACE}=6 ]
  def parse_meta(["categories", _rest]) do
    nil
  end

  # [fixed first implicit byte E0]
  def parse_meta(["fixed", rest]) do
    [type, byte, _end] = String.split(rest, [" byte ", "]"])
    {:fixed, {type, to_binary(byte)}}
  end

  # 08D3; [,,]
  # 2F801; [U+4E38]
  # 2F02; [U+4E36, 10]
  # 2E80; [U+4E36, 70, 05]
  # FE77; [, E6 CF, 20]
  # 18CD5; [7D B2 F4, 05, 05]
  # FC5F; [, E6 6C, 20][, E8 1D, 2E]
  @zero <<0::8>>

  def parse_element(element) when is_binary(element) do
    element
    |> String.split("]")
    |> Enum.reject(&(&1 in ["\n", ""]))
    |> Enum.map(&parse_each_element/1)
    |> maybe_get_head()
  end

  def parse_element([codepoints, rest]) do
    {utf8(codepoints), parse_element(rest)}
  end

  def maybe_get_head([element]) do
    element
  end

  def maybe_get_head(elements) do
    elements
  end

  @splitter ["[", ", ", ",", "]"]
  def parse_each_element(element) do
    element
    |> String.split(@splitter)
    |> assemble_collation_element
  end

  def assemble_collation_element(["", "X", "X", tertiary]),
    do: {nil, nil, to_binary(tertiary)}

  def assemble_collation_element(["", "X", secondary, "X"]),
    do: {nil, to_binary(secondary), nil}

  def assemble_collation_element(["", "", "", ""]),
    do: {@zero, @zero, @zero}

  def assemble_collation_element(["", "U+" <> rest]),
    do: {:copy, utf8(rest)}

  def assemble_collation_element(["", "U+" <> rest, tertiary]),
    do: {:copy, utf8(rest), [tertiary: to_binary(tertiary)]}

  def assemble_collation_element(["", "U+" <> rest, secondary, tertiary]),
    do: {:copy, utf8(rest), [secondary: to_binary(secondary), tertiary: to_binary(tertiary)]}

  def assemble_collation_element(["", "", "", tertiary]),
    do: {@zero, @zero, to_binary(tertiary)}

  def assemble_collation_element(["", "", secondary, tertiary]),
    do: {@zero, to_binary(secondary), to_binary(tertiary)}

  def assemble_collation_element(["", primary, secondary, tertiary]),
    do: {to_binary(primary), to_binary(secondary), to_binary(tertiary)}

  def to_binary(weight) do
    weight
    |> String.split(" ")
    |> Enum.map(&String.to_integer(&1, 16))
    |> :binary.list_to_bin
  end

  def utf8(codepoints) when is_binary(codepoints) do
    case String.split(codepoints, " | ") do
      [prefix, codepoints] ->
        utf8([:prefix, prefix, codepoints])

      [codepoints] ->
        codepoints
        |> String.split(" ")
        |> utf8
    end
  end

  def utf8([:prefix, prefix, codepoints]) do
    {:prefix, to_utf8(prefix), to_utf8(codepoints)}
  end

  def utf8([codepoint]) do
    to_utf8(codepoint)
  end

  def utf8(codepoints) when is_list(codepoints) do
    Enum.map(codepoints, &to_utf8/1)
  end

  def to_utf8(codepoint) do
    {codepoint, ""} = Integer.parse(codepoint, 16)
    codepoint
  end

end