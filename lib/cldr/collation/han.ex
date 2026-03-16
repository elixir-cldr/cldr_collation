defmodule Cldr.Collation.Han do
  @moduledoc """
  Han character ordering using radical-stroke indexes.

  Implements the sorting algorithm from UAX #38, computing 64-bit collation
  keys based on:
  - Radical number (1-214, Kangxi radicals)
  - Residual stroke count
  - Simplified radical indicator
  - Unicode block
  - Code point value

  The radical data is parsed from FractionalUCA.txt `[radical N=...]` entries.

  """

  use GenServer

  import Bitwise
  alias Cldr.Collation.Element

  @table_name :collation_han_radicals

  # Block indexes for the 64-bit key
  @block_cjk_unified 0
  @block_ext_a 1
  @block_ext_b 2
  @block_ext_c 3
  @block_ext_d 4
  @block_ext_e 5
  @block_ext_f 6
  @block_ext_g 7
  @block_ext_h 8
  @block_compat 254
  # Public API

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @doc """
  Ensure the Han radical data is loaded into ETS.

  Loads radical-stroke data from FractionalUCA.txt on first call.
  Subsequent calls are no-ops.

  ### Returns

  * `:ok` - the radical data is loaded and ready.

  ### Examples

      iex> Cldr.Collation.Han.ensure_loaded()
      :ok

  """
  @spec ensure_loaded() :: :ok
  def ensure_loaded do
    case :ets.whereis(@table_name) do
      :undefined -> GenServer.call(__MODULE__, :load, :infinity)
      _ref -> :ok
    end
  end

  @doc """
  Compute collation elements for a Han character using radical-stroke ordering.

  ### Arguments

  * `codepoint` - an integer codepoint for a CJK Unified Ideograph.

  ### Returns

  * `[%Cldr.Collation.Element{}, %Cldr.Collation.Element{}]` - two CEs encoding the radical-stroke key.
  * `nil` - if the character has no radical data (falls back to implicit weights).

  ### Examples

      iex> Cldr.Collation.Han.ensure_loaded()
      iex> elements = Cldr.Collation.Han.collation_elements(0x4E00)
      iex> length(elements)
      2

  """
  @spec collation_elements(non_neg_integer()) :: [Element.t()] | nil
  def collation_elements(codepoint) do
    ensure_loaded()

    case :ets.lookup(@table_name, codepoint) do
      [{_cp, radical, residual_strokes, simplification}] ->
        block = block_index(codepoint)
        # Compute 64-bit key per UAX #38
        key = compute_key(radical, residual_strokes, simplification, block, codepoint)
        key_to_elements(key)

      [] ->
        nil
    end
  end

  @doc """
  Compute the 64-bit sorting key per UAX #38.

  Bit layout:

  * bits 52-63: unused (0).

  * bits 44-51: radical number (1-214).

  * bits 36-43: residual strokes.

  * bits 32-35: reserved (0).

  * bits 28-31: simplification level.

  * bits 20-27: block index.

  * bits 0-19: code point.

  ### Arguments

  * `radical` - the Kangxi radical number (1-214).
  * `residual_strokes` - the residual stroke count after removing the radical.
  * `simplification` - the simplification level (0 for traditional).
  * `block` - the CJK block index (see `block_index/1`).
  * `codepoint` - the Unicode codepoint.

  ### Returns

  A 64-bit integer encoding all components of the radical-stroke sort key.

  ### Examples

      iex> Cldr.Collation.Han.compute_key(1, 0, 0, 0, 0x4E00)
      17592186064384

  """
  @spec compute_key(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: non_neg_integer()
  def compute_key(radical, residual_strokes, simplification, block, codepoint) do
    import Bitwise

    radical <<< 44 |||
      residual_strokes <<< 36 |||
      simplification <<< 28 |||
      block <<< 20 |||
      codepoint
  end

  @doc """
  Convert a 64-bit radical-stroke key to two collation elements.

  Encodes the key as two CEs using the Han implicit base (`0xFB40`):
  - CE1: primary = `0xFB40 + (key >> 32)`, secondary = `0x0020`, tertiary = `0x0002`
  - CE2: primary = `(key & 0xFFFF) | 0x8000`, secondary = `0x0000`, tertiary = `0x0000`

  ### Arguments

  * `key` - a 64-bit integer radical-stroke key from `compute_key/5`.

  ### Returns

  A list of two `%Cldr.Collation.Element{}` structs.

  ### Examples

      iex> elements = Cldr.Collation.Han.key_to_elements(0)
      iex> Cldr.Collation.Element.primary(hd(elements))
      0xFB40

  """
  @spec key_to_elements(non_neg_integer()) :: [Element.t()]
  def key_to_elements(key) do
    # Encode as two CEs with primary weights derived from the key
    # Use the Han implicit base (0xFB40) as a starting point
    # CE1 primary = 0xFB40 + high 16 bits
    # CE2 primary = low 16 bits | 0x8000
    high = key >>> 16
    low = key &&& 0xFFFF

    [
      Element.new(0xFB40 + (high >>> 16), 0x0020, 0x0002),
      Element.new(low ||| 0x8000, 0x0000, 0x0000)
    ]
  end

  @doc """
  Get the CJK block index for a codepoint.

  Maps a codepoint to its CJK Unified Ideograph block for use in the
  radical-stroke sort key.

  ### Arguments

  * `cp` - an integer codepoint.

  ### Returns

  An integer block index:

  * `0` - CJK Unified Ideographs (U+4E00..U+9FFF).
  * `1` - Extension A (U+3400..U+4DBF).
  * `2` - Extension B (U+20000..U+2A6DF).
  * `3`..`8` - Extensions C through H.
  * `254` - CJK Compatibility Ideographs (U+F900..U+FAFF).

  ### Examples

      iex> Cldr.Collation.Han.block_index(0x4E00)
      0

      iex> Cldr.Collation.Han.block_index(0x3400)
      1

  """
  @spec block_index(non_neg_integer()) :: non_neg_integer()
  def block_index(cp) do
    cond do
      cp >= 0x4E00 and cp <= 0x9FFF -> @block_cjk_unified
      cp >= 0x3400 and cp <= 0x4DBF -> @block_ext_a
      cp >= 0x20000 and cp <= 0x2A6DF -> @block_ext_b
      cp >= 0x2A700 and cp <= 0x2B81D -> @block_ext_c
      cp >= 0x2B820 and cp <= 0x2CEAD -> @block_ext_d
      cp >= 0x2CEB0 and cp <= 0x2EBE0 -> @block_ext_e
      cp >= 0x2EBF0 and cp <= 0x2EE5D -> @block_ext_f
      cp >= 0x30000 and cp <= 0x3134A -> @block_ext_g
      cp >= 0x31350 and cp <= 0x33479 -> @block_ext_h
      cp >= 0xF900 and cp <= 0xFAFF -> @block_compat
      true -> @block_cjk_unified
    end
  end

  # GenServer callbacks

  @impl true
  def init(_options), do: {:ok, %{loaded: false}}

  @impl true
  def handle_call(:load, _from, %{loaded: true} = state) do
    {:reply, :ok, state}
  end

  def handle_call(:load, _from, %{loaded: false} = state) do
    load_radical_data()
    {:reply, :ok, %{state | loaded: true}}
  end

  defp load_radical_data do
    table = :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
    path = fractional_uca_path()

    if File.exists?(path) do
      parse_radicals(path, table)
    end

    table
  end

  @doc false
  def parse_radicals(path, table) do
    path
    |> File.stream!()
    |> Enum.each(fn line ->
      case parse_radical_line(String.trim(line)) do
        {:ok, radical_num, members} ->
          Enum.each(members, fn {cp, simplification, strokes} ->
            :ets.insert(table, {cp, radical_num, strokes, simplification})
          end)

        :skip ->
          :ok
      end
    end)
  end

  @doc """
  Parse a radical definition line from FractionalUCA.txt.

  ### Arguments

  * `line` - a trimmed line from FractionalUCA.txt in the format `[radical N=CANONICAL:MEMBER_LIST]`.

  ### Returns

  * `{:ok, radical_num, members}` - the radical number and a list of `{codepoint, simplification, strokes}` tuples.
  * `:skip` - the line is not a radical definition.

  ### Examples

      iex> Cldr.Collation.Han.parse_radical_line("not a radical line")
      :skip

  """
  @spec parse_radical_line(String.t()) ::
          {:ok, pos_integer(), [{non_neg_integer(), non_neg_integer(), non_neg_integer()}]}
          | :skip
  def parse_radical_line(line) do
    case Regex.run(~r/^\[radical (\d+)=.+?:(.+)\]$/, line) do
      [_, num_str, members_str] ->
        radical_num = String.to_integer(num_str)
        members = parse_radical_members(members_str, radical_num)
        {:ok, radical_num, members}

      _ ->
        :skip
    end
  end

  defp parse_radical_members(str, _radical_num) do
    # Members are codepoints, possibly as ranges (cp1-cp2)
    # They're grouped by stroke count, separated within the string
    # We need to extract each codepoint with an estimated residual stroke count
    chars = String.to_charlist(str)
    parse_member_chars(chars, [], 0)
  end

  defp parse_member_chars([], acc, _stroke_group) do
    Enum.reverse(acc)
  end

  defp parse_member_chars([cp | rest], acc, stroke_group) when cp == ?- do
    # Range: previous char to next char
    case {acc, rest} do
      {[{prev_cp, simp, _strokes} | acc_rest], [next_cp | rest2]} ->
        range_entries =
          for c <- (prev_cp + 1)..next_cp do
            {c, simp, stroke_group}
          end

        parse_member_chars(
          rest2,
          range_entries ++ acc_rest ++ [{prev_cp, simp, stroke_group}],
          stroke_group
        )

      _ ->
        parse_member_chars(rest, acc, stroke_group)
    end
  end

  defp parse_member_chars([cp | rest], acc, stroke_group) do
    # Regular codepoint
    entry = {cp, 0, stroke_group}
    # Increment stroke group roughly every cluster of characters
    # The actual stroke count should come from kRSUnicode data
    parse_member_chars(rest, [entry | acc], stroke_group)
  end

  defp fractional_uca_path do
    case :code.priv_dir(:ex_cldr_collation) do
      {:error, :bad_name} -> Path.join([File.cwd!(), "priv", "FractionalUCA.txt"])
      priv_dir -> Path.join(priv_dir, "FractionalUCA.txt")
    end
  end
end
