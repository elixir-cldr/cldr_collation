defmodule Collation.Reorder do
  @moduledoc """
  Script reordering for collation (kr= / reorder option).

  Remaps primary weight lead bytes to change the relative order of scripts.
  For example, `reorder: ["Grek", "Latn"]` would sort Greek characters
  before Latin characters.

  The reorder groups and their lead byte ranges are parsed from FractionalUCA.txt.
  """

  import Bitwise

  @doc """
  Build a reorder mapping function from the given script codes.

  Creates a function that remaps primary weight lead bytes to reorder scripts.
  Core codes (space, punct, symbol, currency, digit) that are not explicitly
  listed are prepended automatically.

  ### Arguments

  * `reorder_codes` - a list of script code strings (e.g., `["Grek", "Latn"]`).
    Supports ISO 15924 codes (`"Latn"`, `"Grek"`, `"Cyrl"`) and special codes
    (`"space"`, `"punct"`, `"symbol"`, `"currency"`, `"digit"`, `"others"`).

  ### Returns

  * A function `(primary :: integer()) -> integer()` that remaps primary weights
  * `nil` if the list is empty or no valid mappings were found

  ### Examples

      iex> Collation.Reorder.build_mapping([])
      nil

      iex> mapping = Collation.Reorder.build_mapping(["Grek", "Latn"])
      iex> is_function(mapping, 1)
      true
  """
  def build_mapping([]), do: nil

  def build_mapping(reorder_codes) do
    # Get the script-to-lead-byte mapping
    script_ranges = load_script_ranges()

    # Build the new ordering
    # Special codes: space, punct, symbol, currency, digit
    # Script codes: Latn, Grek, Cyrl, etc.
    # "others" / "Zzzz": everything not explicitly listed

    # Collect lead byte ranges for each code in order
    {ordered_ranges, remaining} =
      Enum.reduce(reorder_codes, {[], script_ranges}, fn code, {ordered, remaining} ->
        normalized = normalize_code(code)

        case Map.pop(remaining, normalized) do
          {nil, remaining} ->
            {ordered, remaining}

          {range, remaining} ->
            {[{normalized, range} | ordered], remaining}
        end
      end)

    ordered_ranges = Enum.reverse(ordered_ranges)

    # Check if "others"/"Zzzz" is in the list
    has_others = Enum.any?(reorder_codes, fn c -> c in ["others", "Zzzz"] end)

    # Build the final ordering
    # Missing core codes (space, punct, symbol, currency, digit) are prepended
    core_codes = ["space", "punct", "symbol", "currency", "digit"]

    missing_core =
      Enum.filter(core_codes, fn c ->
        not Enum.any?(reorder_codes, &(normalize_code(&1) == c))
      end)

    core_entries =
      Enum.flat_map(missing_core, fn c ->
        case Map.get(script_ranges, c) do
          nil -> []
          range -> [{c, range}]
        end
      end)

    # Others = remaining scripts not explicitly listed
    others_entries =
      if has_others do
        []
      else
        remaining
        |> Map.drop(core_codes)
        |> Enum.sort_by(fn {_k, {start, _end}} -> start end)
      end

    all_entries = core_entries ++ ordered_ranges ++ others_entries

    # Build a lead byte remapping table
    build_lead_byte_remap(all_entries)
  end

  defp build_lead_byte_remap(entries) do
    # Assign new lead bytes sequentially
    {remap, _next} =
      Enum.reduce(entries, {%{}, 0x03}, fn {_code, {range_start, range_end}}, {remap, next} ->
        count = range_end - range_start + 1

        new_mappings =
          Enum.zip(range_start..range_end, next..(next + count - 1))
          |> Map.new()

        {Map.merge(remap, new_mappings), next + count}
      end)

    if map_size(remap) == 0 do
      nil
    else
      fn primary ->
        if primary == 0 do
          0
        else
          lead_byte = primary >>> 8

          case Map.get(remap, lead_byte) do
            nil -> primary
            new_lead -> new_lead <<< 8 ||| (primary &&& 0xFF)
          end
        end
      end
    end
  end

  defp normalize_code(code) do
    code
    |> String.downcase()
    |> case do
      "latn" -> "latin"
      "grek" -> "greek"
      "cyrl" -> "cyrillic"
      "hang" -> "hangul"
      "hira" -> "hiragana"
      "kana" -> "katakana"
      "hani" -> "han"
      other -> other
    end
  end

  @doc """
  Load the script-to-lead-byte-range mapping from FractionalUCA.txt.

  Parses `[top_byte ...]` entries from the data file. Falls back to
  hardcoded defaults if the file is not found.

  ### Returns

  A map `%{String.t() => {start_byte, end_byte}}` where keys are lowercase
  script/group names and values are lead byte range tuples.

  ### Examples

      iex> ranges = Collation.Reorder.load_script_ranges()
      iex> is_map(ranges)
      true
  """
  def load_script_ranges do
    path = fractional_uca_path()

    if File.exists?(path) do
      parse_top_bytes(path)
    else
      default_script_ranges()
    end
  end

  defp parse_top_bytes(path) do
    path
    |> File.stream!()
    |> Enum.reduce(%{}, fn line, acc ->
      case Regex.run(~r/^\[top_byte\s+([0-9A-Fa-f]+)\s+(.+?)\s*\]/, line) do
        [_, hex, group_name] ->
          byte = String.to_integer(hex, 16)
          groups = group_name |> String.downcase() |> String.split() |> Enum.map(&String.trim/1)

          Enum.reduce(groups, acc, fn group, inner_acc ->
            case Map.get(inner_acc, group) do
              nil -> Map.put(inner_acc, group, {byte, byte})
              {start, _end} -> Map.put(inner_acc, group, {start, byte})
            end
          end)

        _ ->
          acc
      end
    end)
  end

  defp fractional_uca_path do
    case :code.priv_dir(:collation) do
      {:error, :bad_name} ->
        Path.join([File.cwd!(), "priv", "FractionalUCA.txt"])

      priv_dir ->
        Path.join(priv_dir, "FractionalUCA.txt")
    end
  end

  # Default ranges based on UCA 17.0.0
  defp default_script_ranges do
    %{
      "space" => {0x03, 0x04},
      "punctuation" => {0x05, 0x0B},
      "punct" => {0x05, 0x0B},
      "symbol" => {0x0C, 0x0C},
      "currency" => {0x0D, 0x0E},
      "digit" => {0x0F, 0x27},
      "latin" => {0x2A, 0x5F},
      "greek" => {0x61, 0x61},
      "cyrillic" => {0x62, 0x62},
      "han" => {0x81, 0xE3},
      "hangul" => {0x7C, 0x7C}
    }
  end

  @doc """
  Apply a reorder mapping to a primary weight.

  ### Arguments

  * `mapping_fn` - a reorder mapping function from `build_mapping/1`, or `nil`
  * `primary` - the primary weight to remap

  ### Returns

  The remapped primary weight, or the original if `mapping_fn` is `nil`.

  ### Examples

      iex> Collation.Reorder.apply_mapping(nil, 0x2A00)
      0x2A00

      iex> mapping = Collation.Reorder.build_mapping(["Grek", "Latn"])
      iex> remapped = Collation.Reorder.apply_mapping(mapping, 0x2A00)
      iex> is_integer(remapped)
      true
  """
  def apply_mapping(nil, primary), do: primary
  def apply_mapping(mapping_fn, primary), do: mapping_fn.(primary)
end
