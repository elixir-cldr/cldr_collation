defmodule Cldr.Collation.Table.Parser do
  @moduledoc """
  Parses the allkeys_CLDR.txt file into a map of codepoint sequences to collation elements.

  Format: `CODEPOINTS ; [.PPPP.SSSS.TTTT]... # comment`

  * Single codepoint: `0041 ; [.23EC.0020.0008] # LATIN CAPITAL LETTER A`.

  * Multi-CE: `00E9 ; [.2453.0020.0002][.0000.0024.0002] # LATIN SMALL LETTER E WITH ACUTE`.

  * Contraction: `006C 00B7 ; [.2528.0020.0002][.0000.011F.0002] # LATIN SMALL LETTER L, MIDDLE DOT`.

  """

  alias Cldr.Collation.Element

  @doc """
  Parse the allkeys_CLDR.txt file into a collation table.

  ### Arguments

  * `path` - file path to the allkeys_CLDR.txt data file.

  ### Returns

  A map with two keys:

  * `:entries` - `%{integer() | tuple() => [%Cldr.Collation.Element{}]}` mapping codepoints (integers for single, tuples for contractions) to collation elements.
  * `:version` - the UCA version string from the file header, or `nil`.

  ### Examples

      iex> result = Cldr.Collation.Table.Parser.parse("priv/allkeys_CLDR.txt")
      iex> is_map(result.entries) and is_binary(result.version)
      true

  """
  def parse(path) do
    path
    |> File.stream!()
    |> Enum.reduce(%{entries: %{}, version: nil}, fn line, acc ->
      line = String.trim(line)

      cond do
        String.starts_with?(line, "@version") ->
          version = line |> String.replace("@version ", "") |> String.trim()
          %{acc | version: version}

        String.starts_with?(line, "#") or line == "" ->
          acc

        true ->
          case parse_entry(line) do
            {:ok, codepoints, elements} ->
              key = codepoints_to_key(codepoints)
              %{acc | entries: Map.put(acc.entries, key, elements)}

            :skip ->
              acc
          end
      end
    end)
  end

  @doc """
  Parse a single allkeys entry line.

  ### Arguments

  * `line` - a single line from the allkeys file (e.g., `"0041 ; [.23EC.0020.0008] # LATIN CAPITAL LETTER A"`).

  ### Returns

  * `{:ok, codepoints, elements}` - the parsed codepoint list and collation elements.
  * `:skip` - the line could not be parsed.

  ### Examples

      iex> {:ok, cps, elems} = Cldr.Collation.Table.Parser.parse_entry("0041 ; [.23EC.0020.0008] # LATIN CAPITAL LETTER A")
      iex> cps
      [65]
      iex> hd(elems)
      {0x23EC, 0x0020, 0x0008, false}

  """
  def parse_entry(line) do
    case String.split(line, ";", parts: 2) do
      [cp_part, rest] ->
        codepoints = parse_codepoints(String.trim(cp_part))
        # Strip comment
        weight_part =
          case String.split(rest, "#", parts: 2) do
            [w, _comment] -> String.trim(w)
            [w] -> String.trim(w)
          end

        elements = parse_elements(weight_part)
        {:ok, codepoints, elements}

      _ ->
        :skip
    end
  end

  defp parse_codepoints(str) do
    str
    |> String.split()
    |> Enum.map(&String.to_integer(&1, 16))
  end

  @doc """
  Convert a codepoint list to a table key.

  Single codepoints become bare integers, multi-codepoint sequences (contractions)
  become tuples for compact persistent_term storage.

  ### Arguments

  * `codepoints` - a list of integer codepoints.

  ### Returns

  An integer for single codepoints, or a tuple for contractions.

  ### Examples

      iex> Cldr.Collation.Table.Parser.codepoints_to_key([0x0041])
      0x0041

      iex> Cldr.Collation.Table.Parser.codepoints_to_key([0x006C, 0x00B7])
      {0x006C, 0x00B7}

  """
  def codepoints_to_key([cp]), do: cp
  def codepoints_to_key(cps) when is_list(cps), do: List.to_tuple(cps)

  @doc """
  Parse weight elements from an allkeys weight string.

  Handles both regular (`[.PPPP.SSSS.TTTT]`) and variable (`[*PPPP.SSSS.TTTT]`)
  entries. The `*` prefix marks variable-weight elements (spaces, punctuation)
  in the CLDR allkeys file.

  ### Arguments

  * `str` - the weight portion of an allkeys line (e.g., `"[.23EC.0020.0008]"`).

  ### Returns

  A list of collation element tuples `{primary, secondary, tertiary, variable}`.

  ### Examples

      iex> Cldr.Collation.Table.Parser.parse_elements("[.23EC.0020.0008]")
      [{0x23EC, 0x0020, 0x0008, false}]

      iex> Cldr.Collation.Table.Parser.parse_elements("[*0269.0020.0002]")
      [{0x0269, 0x0020, 0x0002, true}]

  """
  def parse_elements(str) do
    ~r/\[([.*])([0-9A-Fa-f]{4})\.([0-9A-Fa-f]{4})\.([0-9A-Fa-f]{4})\]/
    |> Regex.scan(str)
    |> Enum.map(fn [_full, marker, p, s, t] ->
      Element.new(
        String.to_integer(p, 16),
        String.to_integer(s, 16),
        String.to_integer(t, 16),
        marker == "*"
      )
    end)
  end

  @doc """
  Parse FractionalUCA.txt to extract entries not already in allkeys_CLDR.txt.

  Supplements the allkeys table with additional entries (notably Tangut, Nushu,
  and Khitan characters) by extracting decimal weights from the comment portion
  of FractionalUCA lines.

  ### Arguments

  * `path` - file path to the FractionalUCA.txt data file.
  * `existing_entries` - the map of entries already parsed from allkeys_CLDR.txt.

  ### Returns

  An updated entries map `%{integer() | tuple() => [%Cldr.Collation.Element{}]}` with new
  entries merged in. Existing entries are never overwritten.

  ### Examples

      iex> existing = %{0x0041 => [{0x23EC, 0x0020, 0x0008, false}]}
      iex> result = Cldr.Collation.Table.Parser.parse_fractional_supplement("priv/FractionalUCA.txt", existing)
      iex> map_size(result) > map_size(existing)
      true

  """
  def parse_fractional_supplement(path, existing_entries) do
    path
    |> File.stream!()
    |> Enum.reduce(existing_entries, fn line, acc ->
      line = String.trim(line)

      cond do
        # Skip comments, empty lines, metadata, and FDD markers
        line == "" or String.starts_with?(line, "#") or
          String.starts_with?(line, "[") or
            String.starts_with?(line, "FDD") ->
          acc

        # Data entry
        String.contains?(line, ";") ->
          case parse_fractional_entry(line) do
            {:ok, codepoints, elements} when elements != [] ->
              key = codepoints_to_key(codepoints)

              # Only add if not already in the table
              if Map.has_key?(acc, key) do
                acc
              else
                Map.put(acc, key, elements)
              end

            _ ->
              acc
          end

        true ->
          acc
      end
    end)
  end

  @doc """
  Parse a single FractionalUCA.txt data entry.

  Extracts codepoints and decimal weights from a FractionalUCA line. Context
  entries (containing `|`) are skipped.

  ### Arguments

  * `line` - a single data line from FractionalUCA.txt.

  ### Returns

  * `{:ok, codepoints, elements}` - the parsed codepoint list and collation elements.
  * `:skip` - the line could not be parsed or is a context entry.

  ### Examples

      iex> Cldr.Collation.Table.Parser.parse_fractional_entry("invalid line")
      :skip

  """
  def parse_fractional_entry(line) do
    case String.split(line, ";", parts: 2) do
      [cp_part, rest] ->
        cp_str = String.trim(cp_part)

        # Skip context entries (contain | character)
        if String.contains?(cp_str, "|") do
          :skip
        else
          codepoints = parse_codepoints(cp_str)

          # Extract decimal weights from brackets after the # comment marker
          # Format: [PPPP.SSSS.TTTT][PPPP.SSSS.TTTT]...
          case Regex.run(~r/#.*?(\[.+)$/, rest) do
            [_, weights_and_name] ->
              # The weights are inside brackets, followed by * NAME
              # Extract just the weight brackets
              elements = parse_fractional_weights(weights_and_name)
              {:ok, codepoints, elements}

            nil ->
              :skip
          end
        end

      _ ->
        :skip
    end
  end

  defp parse_fractional_weights(str) do
    # Match [PPPP.SSSS.TTTT] patterns (allkeys decimal format)
    ~r/\[([0-9A-Fa-f]{4})\.([0-9A-Fa-f]{4})\.([0-9A-Fa-f]{4})\]/
    |> Regex.scan(str)
    |> Enum.map(fn [_full, p, s, t] ->
      Element.new(
        String.to_integer(p, 16),
        String.to_integer(s, 16),
        String.to_integer(t, 16)
      )
    end)
  end
end
