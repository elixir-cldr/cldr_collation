defmodule Collation.Table.Parser do
  @moduledoc """
  Parses the allkeys_CLDR.txt file into a map of codepoint sequences to collation elements.

  Format: `CODEPOINTS ; [.PPPP.SSSS.TTTT]... # comment`
  - Single codepoint: `0041 ; [.23EC.0020.0008] # LATIN CAPITAL LETTER A`
  - Multi-CE: `00E9 ; [.2453.0020.0002][.0000.0024.0002] # LATIN SMALL LETTER E WITH ACUTE`
  - Contraction: `006C 00B7 ; [.2528.0020.0002][.0000.011F.0002] # LATIN SMALL LETTER L, MIDDLE DOT`
  """

  alias Collation.Element

  @doc """
  Parses the allkeys file and returns:
  - `entries`: %{[codepoint_list] => [%Element{}, ...]}`
  - `version`: the UCA version string
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
              %{acc | entries: Map.put(acc.entries, codepoints, elements)}

            :skip ->
              acc
          end
      end
    end)
  end

  @doc "Parse a single allkeys entry line."
  def parse_entry(line) do
    case String.split(line, ";", parts: 2) do
      [cp_part, rest] ->
        codepoints = parse_codepoints(String.trim(cp_part))
        # Strip comment
        weight_part = case String.split(rest, "#", parts: 2) do
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
  Parse weight elements.

  Handles both regular `[.23EC.0020.0008]` and variable `[*0269.0020.0002]` entries.
  The `*` prefix marks variable-weight elements (space, punctuation) in CLDR allkeys.
  """
  def parse_elements(str) do
    ~r/\[([.*])([0-9A-Fa-f]{4})\.([0-9A-Fa-f]{4})\.([0-9A-Fa-f]{4})\]/
    |> Regex.scan(str)
    |> Enum.map(fn [_full, marker, p, s, t] ->
      %Element{
        primary: String.to_integer(p, 16),
        secondary: String.to_integer(s, 16),
        tertiary: String.to_integer(t, 16),
        variable: marker == "*"
      }
    end)
  end

  @doc """
  Parse FractionalUCA.txt to extract entries not already in allkeys_CLDR.txt.

  FractionalUCA lines have the format:
  `CODEPOINTS; [fractional_hex]  # Script  [PPPP.SSSS.TTTT]...  * NAME`

  The decimal weights in brackets (after the #) match the allkeys format.
  We extract these to supplement the allkeys table with additional entries
  (notably Tangut, Nushu, Khitan characters).
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
              # Only add if not already in the table
              if Map.has_key?(acc, codepoints) do
                acc
              else
                Map.put(acc, codepoints, elements)
              end

            _ ->
              acc
          end

        true ->
          acc
      end
    end)
  end

  @doc "Parse a FractionalUCA.txt data entry."
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
      %Element{
        primary: String.to_integer(p, 16),
        secondary: String.to_integer(s, 16),
        tertiary: String.to_integer(t, 16)
      }
    end)
  end
end
