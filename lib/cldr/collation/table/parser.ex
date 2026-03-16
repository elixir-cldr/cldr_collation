defmodule Cldr.Collation.Table.Parser do
  @moduledoc """
  Parses the FractionalUCA.txt file into a map of codepoint sequences to collation elements.

  FractionalUCA.txt is the single source of truth for the collation table. Each data line
  contains both fractional weights (used for script reordering) and allkeys-format decimal
  weights (used for collation element construction) in the comment:

  * Single codepoint: `0041; [2B, 05, 9C]  # Latn Lu  [23EC.0020.0008]  * LATIN CAPITAL LETTER A`.

  * Multi-CE: `00E9; [2B 86, 05, 05]  # Latn Ll  [2453.0020.0002][0000.0024.0002]  * LATIN SMALL LETTER E WITH ACUTE`.

  * Context entry: `004C | 00B7; [, FB B6, 05]  # Zyyy Po  [0000.011F.0002]  * MIDDLE DOT`.

  Context entries represent CLDR-specific contractions where a target codepoint's weights
  change depending on the preceding context codepoint. These are converted to explicit
  contraction entries (e.g., `{0x004C, 0x00B7} => L's CEs ++ modified CEs`).

  Variable status (spaces, punctuation, symbols, currency) is derived from the
  `[last variable]` header line rather than per-entry markers.

  """

  alias Cldr.Collation.Element

  # The allkeys primary weight boundaries for variable elements, parsed from
  # [first variable ...] and [last variable ...] in FractionalUCA.txt.
  # Entries with first_variable_primary <= primary <= last_variable_primary
  # are variable (spaces, punctuation, symbols, currency).
  @default_first_variable_primary 0x0201
  @default_last_variable_primary 0x04E0

  @doc """
  Parse FractionalUCA.txt into a collation table.

  This is the primary parser that builds the complete collation table from
  a single data file. Variable status is derived from the `[last variable]`
  header line.

  ### Arguments

  * `path` - file path to the FractionalUCA.txt data file.

  ### Returns

  A map with two keys:

  * `:entries` - `%{integer() | tuple() => [Element.t()]}` mapping codepoints
    (integers for single, tuples for contractions) to collation elements.

  * `:version` - the UCA version string from the file header, or `nil`.

  ### Examples

      iex> result = Cldr.Collation.Table.Parser.parse("priv/FractionalUCA.txt")
      iex> is_map(result.entries) and is_binary(result.version)
      true

  """
  def parse(path) do
    # Two-pass parse:
    # Pass 1: collect entries and last_variable_primary
    # Pass 2: apply variable flags and resolve context entries
    acc =
      path
      |> File.stream!()
      |> Enum.reduce(
        %{
          entries: %{},
          contexts: [],
          version: nil,
          first_variable_primary: @default_first_variable_primary,
          last_variable_primary: @default_last_variable_primary
        },
        fn line, acc ->
          line = String.trim(line)

          cond do
            line == "" or String.starts_with?(line, "#") ->
              acc

            String.starts_with?(line, "[UCA version") ->
              case Regex.run(~r/\[UCA version = (.+)\]/, line) do
                [_, version] -> %{acc | version: String.trim(version)}
                _ -> acc
              end

            String.starts_with?(line, "[first variable") ->
              case parse_variable_boundary(line) do
                {:ok, primary} -> %{acc | first_variable_primary: primary}
                :skip -> acc
              end

            String.starts_with?(line, "[last variable") ->
              case parse_variable_boundary(line) do
                {:ok, primary} -> %{acc | last_variable_primary: primary}
                :skip -> acc
              end

            String.starts_with?(line, "[") ->
              # Skip other metadata lines ([radical...], [first...], [variable top...], etc.)
              acc

            String.starts_with?(line, "FDD") ->
              # Skip FDD0/FDD1 sentinel entries (script reorder boundaries)
              acc

            String.contains?(line, ";") ->
              case parse_fractional_entry(line) do
                {:ok, codepoints, elements} when elements != [] ->
                  key = codepoints_to_key(codepoints)
                  %{acc | entries: Map.put(acc.entries, key, elements)}

                {:context, context_cp, target_cp, elements} ->
                  %{acc | contexts: [{context_cp, target_cp, elements} | acc.contexts]}

                _ ->
                  acc
              end

            true ->
              acc
          end
        end
      )

    # Apply variable flags based on first/last variable primary boundaries
    variable_range = {acc.first_variable_primary, acc.last_variable_primary}
    entries = apply_variable_flags(acc.entries, variable_range)

    # Resolve context entries into contractions
    entries = resolve_context_entries(acc.contexts, entries, variable_range)

    %{entries: entries, version: acc.version}
  end

  @doc """
  Parse a single FractionalUCA.txt data entry.

  Extracts codepoints and allkeys-format decimal weights from a FractionalUCA line.
  Context entries (containing `|`) are returned as `{:context, ...}` tuples for
  later resolution into contractions.

  ### Arguments

  * `line` - a single data line from FractionalUCA.txt.

  ### Returns

  * `{:ok, codepoints, elements}` - the parsed codepoint list and collation elements.

  * `{:context, context_cp, target_cp, elements}` - a context entry to be resolved later.

  * `:skip` - the line could not be parsed.

  ### Examples

      iex> Cldr.Collation.Table.Parser.parse_fractional_entry("0041; [2B, 05, 9C]\\t# Latn Lu\\t[23EC.0020.0008]\\t* LATIN CAPITAL LETTER A")
      {:ok, [65], [{0x23EC, 0x0020, 0x0008, false}]}

      iex> Cldr.Collation.Table.Parser.parse_fractional_entry("invalid line")
      :skip

  """
  def parse_fractional_entry(line) do
    case String.split(line, ";", parts: 2) do
      [cp_part, rest] ->
        cp_str = String.trim(cp_part)

        if String.contains?(cp_str, "|") do
          parse_context_entry(cp_str, rest)
        else
          codepoints = parse_codepoints(cp_str)

          case extract_allkeys_weights(rest) do
            elements when elements != [] ->
              {:ok, codepoints, elements}

            _ ->
              :skip
          end
        end

      _ ->
        :skip
    end
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

  # Parse a [first variable ...] or [last variable ...] line to extract
  # the allkeys primary weight from the comment.
  # Format: [last variable [0B 8E 64, 05, 05]] # U+1E5FF ... [04E0.0020.0002]
  defp parse_variable_boundary(line) do
    case Regex.run(~r/\[([0-9A-Fa-f]{4})\.[0-9A-Fa-f]{4}\.[0-9A-Fa-f]{4}\]/, line) do
      [_, primary_hex] -> {:ok, String.to_integer(primary_hex, 16)}
      _ -> :skip
    end
  end

  # Parse a context entry: "004C | 00B7; ..." → {:context, 0x004C, 0x00B7, elements}
  defp parse_context_entry(cp_str, rest) do
    case String.split(cp_str, "|") do
      [context_str, target_str] ->
        [context_cp] = parse_codepoints(String.trim(context_str))
        [target_cp] = parse_codepoints(String.trim(target_str))

        case extract_allkeys_weights(rest) do
          elements when elements != [] ->
            {:context, context_cp, target_cp, elements}

          _ ->
            :skip
        end

      _ ->
        :skip
    end
  end

  # Extract allkeys-format [PPPP.SSSS.TTTT] weights from the comment portion
  # of a FractionalUCA line. These appear after the # marker.
  # Falls back to parsing fractional weights for special entries (FFFE, FFFF)
  # that lack allkeys-format comments.
  defp extract_allkeys_weights(rest) do
    elements =
      case Regex.run(~r/#.*?(\[.+)$/, rest) do
        [_, weights_section] ->
          ~r/\[([0-9A-Fa-f]{4})\.([0-9A-Fa-f]{4})\.([0-9A-Fa-f]{4})\]/
          |> Regex.scan(weights_section)
          |> Enum.map(fn [_full, p, s, t] ->
            Element.new(
              String.to_integer(p, 16),
              String.to_integer(s, 16),
              String.to_integer(t, 16)
            )
          end)

        nil ->
          []
      end

    if elements != [] do
      elements
    else
      # No allkeys-format weights in comment — try fractional weights
      # This handles special entries like FFFE and FFFF
      parse_fractional_as_allkeys(rest)
    end
  end

  # Parse fractional weights for special entries that lack allkeys-format
  # comments (e.g., FFFE "LOWEST primary" and FFFF "HIGHEST primary").
  # Maps single-byte fractional primaries to their allkeys equivalents:
  #   0x02 → 0x0001 (FFFE: lowest primary)
  #   0xEF → 0xFFFE (FFFF: highest primary, encoded as [EF FF, ...])
  defp parse_fractional_as_allkeys(rest) do
    # Extract the fractional weight portion before the comment
    weight_part =
      case String.split(rest, "#", parts: 2) do
        [w, _] -> String.trim(w)
        [w] -> String.trim(w)
      end

    cond do
      # FFFE: [02, 05, 05] → primary = 0x0001
      String.contains?(weight_part, "[02, 05, 05]") ->
        [Element.new(0x0001, 0x0020, 0x0002)]

      # FFFF: [EF FF, 05, 05] → primary = 0xFFFE
      String.contains?(weight_part, "[EF FF, 05, 05]") ->
        [Element.new(0xFFFE, 0x0020, 0x0002)]

      true ->
        []
    end
  end

  # Apply variable flags to all entries based on the variable primary range.
  # An element is variable if first_variable_primary <= primary <= last_variable_primary.
  defp apply_variable_flags(entries, {first_variable, last_variable}) do
    Map.new(entries, fn {key, elements} ->
      flagged =
        Enum.map(elements, fn {p, s, t, _v} ->
          variable = p >= first_variable and p <= last_variable
          {p, s, t, variable}
        end)

      {key, flagged}
    end)
  end

  # Resolve context entries into contraction entries.
  # A context entry "CONTEXT_CP | TARGET_CP" with modified CEs becomes
  # a contraction key {CONTEXT_CP, TARGET_CP} with CEs =
  # context_cp's own CEs ++ modified CEs.
  defp resolve_context_entries(contexts, entries, {first_variable, last_variable}) do
    Enum.reduce(contexts, entries, fn {context_cp, target_cp, modified_elements}, acc ->
      case Map.get(acc, context_cp) do
        nil ->
          # Context codepoint not in table — skip
          acc

        context_elements ->
          # Flag the modified elements for variable status
          flagged =
            Enum.map(modified_elements, fn {p, s, t, _v} ->
              variable = p >= first_variable and p <= last_variable
              {p, s, t, variable}
            end)

          contraction_key = {context_cp, target_cp}
          contraction_elements = context_elements ++ flagged
          Map.put(acc, contraction_key, contraction_elements)
      end
    end)
  end

  defp parse_codepoints(str) do
    str
    |> String.split()
    |> Enum.map(&String.to_integer(&1, 16))
  end
end
