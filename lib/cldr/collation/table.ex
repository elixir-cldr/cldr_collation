defmodule Cldr.Collation.Table do
  @moduledoc """
  Persistent-term-backed collation element table.

  Stores the collation table parsed from `FractionalUCA.txt` for fast
  concurrent lookups using `:persistent_term`, which provides zero-copy
  reads for data that is written once and never modified.

  Handles both single codepoint mappings and contractions
  (multi-codepoint sequences).

  """

  use GenServer

  alias Cldr.Collation.Element
  alias Cldr.Collation.Table.Parser

  @table_name :collation_table
  @contractions_table :collation_contractions

  @fractional_keys "FractionalUCA.txt"

  @doc """
  Ensure the collation table is loaded.

  Loads the `FractionalUCA.txt` data file on first call. Subsequent calls
  are no-ops.

  ### Returns

  * `:ok` - the table is loaded and ready for lookups.

  ### Examples

      iex> Cldr.Collation.Table.ensure_loaded()
      :ok

  """
  @spec ensure_loaded() :: :ok
  def ensure_loaded do
    case :persistent_term.get(@table_name, nil) do
      nil -> GenServer.call(__MODULE__, :load, :infinity)
      _map -> :ok
    end
  end

  @doc """
  Look up collation elements for a codepoint or codepoint sequence.

  ### Arguments

  * `codepoint` - a single integer codepoint, or a list of integer.
    codepoints (contraction). Lists are internally converted to the
    compact key format (integer for single, tuple for multi).

  ### Returns

  * `{:ok, [%Cldr.Collation.Element{}]}` - the collation elements for.
    the entry.

  * `:unmapped` - no entry found in the table.

  ### Examples

      iex> Cldr.Collation.Table.ensure_loaded()
      iex> {:ok, elements} = Cldr.Collation.Table.lookup(0x0041)
      iex> Cldr.Collation.Element.primary(hd(elements)) > 0
      true

      iex> Cldr.Collation.Table.ensure_loaded()
      iex> Cldr.Collation.Table.lookup(0x10FFFF)
      :unmapped

  """
  @spec lookup(non_neg_integer() | [non_neg_integer()]) :: {:ok, [Element.t()]} | :unmapped
  def lookup(codepoint) when is_integer(codepoint) do
    table = :persistent_term.get(@table_name)

    case Map.get(table, codepoint) do
      nil -> :unmapped
      elements -> {:ok, elements}
    end
  end

  def lookup(codepoints) when is_list(codepoints) do
    table = :persistent_term.get(@table_name)
    key = Parser.codepoints_to_key(codepoints)

    case Map.get(table, key) do
      nil -> :unmapped
      elements -> {:ok, elements}
    end
  end

  @doc """
  Check if a codepoint begins any multi-codepoint contraction.

  ### Arguments

  * `codepoint` - an integer codepoint to check.

  ### Returns

  * A list of contraction lengths that start with this codepoint, or `[]` if.
    this codepoint does not begin any contractions.

  ### Examples

      iex> Cldr.Collation.Table.ensure_loaded()
      iex> lengths = Cldr.Collation.Table.contraction_starters(0x006C)
      iex> is_list(lengths)
      true

  """
  @spec contraction_starters(non_neg_integer()) :: [pos_integer()]
  def contraction_starters(codepoint) do
    contractions = :persistent_term.get(@contractions_table)
    Map.get(contractions, codepoint, [])
  end

  @doc """
  Find the longest matching entry for the given codepoint sequence.

  Tries contractions from longest to shortest, falling back to a single
  codepoint lookup.

  ### Arguments

  * `codepoints` - a list of integer codepoints to match against.

  ### Returns

  * `{matched_cps, elements, remaining_cps}` - a successful match with the.
    matched codepoints, their collation elements, and the remaining unprocessed tail.

  * `{:unmapped, codepoint, remaining_cps}` - the first codepoint has no table entry.

  * `:done` - the input list is empty.

  ### Examples

      iex> Cldr.Collation.Table.ensure_loaded()
      iex> {matched, _elements, rest} = Cldr.Collation.Table.longest_match([0x0041, 0x0042])
      iex> matched
      [65]
      iex> rest
      [66]

  """
  @spec longest_match([non_neg_integer()]) ::
          {[non_neg_integer()], [Element.t()], [non_neg_integer()]}
          | {:unmapped, non_neg_integer(), [non_neg_integer()]}
          | :done
  def longest_match([cp | rest] = _codepoints) do
    # Check if this codepoint starts any contractions
    lengths = contraction_starters(cp)

    if lengths == [] do
      # No contractions, just look up single codepoint
      case lookup(cp) do
        {:ok, elements} -> {[cp], elements, rest}
        :unmapped -> {:unmapped, cp, rest}
      end
    else
      # Try contractions from longest to shortest
      max_len = Enum.max(lengths)
      available = [cp | Enum.take(rest, max_len - 1)]

      result =
        max_len..2//-1
        |> Enum.reduce_while(nil, fn len, _acc ->
          if len <= length(available) do
            candidate = Enum.take(available, len)

            case lookup(candidate) do
              {:ok, elements} ->
                remaining = Enum.drop([cp | rest], len)
                {:halt, {candidate, elements, remaining}}

              :unmapped ->
                {:cont, nil}
            end
          else
            {:cont, nil}
          end
        end)

      case result do
        nil ->
          # No contraction matched, try single codepoint
          case lookup(cp) do
            {:ok, elements} -> {[cp], elements, rest}
            :unmapped -> {:unmapped, cp, rest}
          end

        match ->
          match
      end
    end
  end

  # Note: longest_match returns matched codepoints as lists for downstream compatibility.
  # The lookup functions handle the list-to-key conversion internally.

  def longest_match([]), do: :done

  @doc """
  Look up collation elements with a tailoring overlay checked first.

  ### Arguments

  * `codepoints` - a single integer codepoint, or a list of integer codepoints.

  * `overlay` - a map of `%{key => [%Cldr.Collation.Element{}]}` tailoring.
    entries, where keys are integers (single CP) or tuples (contractions).

  ### Returns

  * Same as `lookup/1`, but checks the overlay map before falling back.
    to the root table.

  ### Examples

      iex> Cldr.Collation.Table.ensure_loaded()
      iex> overlay = %{0x0041 => [{0xFFFF, 0x0020, 0x0008, false}]}
      iex> {:ok, [elem]} = Cldr.Collation.Table.lookup_with_overlay(0x0041, overlay)
      iex> Cldr.Collation.Element.primary(elem)
      0xFFFF

  """
  @spec lookup_with_overlay(non_neg_integer() | [non_neg_integer()], map() | nil) ::
          {:ok, [Element.t()]} | :unmapped
  def lookup_with_overlay(codepoint, overlay) when is_integer(codepoint) do
    lookup_with_overlay_key(codepoint, overlay)
  end

  def lookup_with_overlay(codepoints, overlay) when is_list(codepoints) do
    key = Parser.codepoints_to_key(codepoints)
    lookup_with_overlay_key(key, overlay)
  end

  defp lookup_with_overlay_key(key, nil) do
    table = :persistent_term.get(@table_name)

    case Map.get(table, key) do
      nil -> :unmapped
      elements -> {:ok, elements}
    end
  end

  defp lookup_with_overlay_key(key, overlay) when is_map(overlay) do
    case Map.get(overlay, key) do
      nil ->
        table = :persistent_term.get(@table_name)

        case Map.get(table, key) do
          nil -> :unmapped
          elements -> {:ok, elements}
        end

      elements ->
        {:ok, elements}
    end
  end

  @doc """
  Find the longest matching entry, checking a tailoring overlay first.

  ### Arguments

  * `codepoints` - a list of integer codepoints to match.

  * `overlay` - a tailoring overlay map, or `nil` for root-only lookups.

  ### Returns

  Same as `longest_match/1`.

  ### Examples

      iex> Cldr.Collation.Table.ensure_loaded()
      iex> {matched, _elems, rest} = Cldr.Collation.Table.longest_match_with_overlay([0x0041, 0x0042], nil)
      iex> matched
      [65]
      iex> rest
      [66]

  """
  @spec longest_match_with_overlay([non_neg_integer()], map() | nil) ::
          {[non_neg_integer()], [Element.t()], [non_neg_integer()]}
          | {:unmapped, non_neg_integer(), [non_neg_integer()]}
          | :done
  def longest_match_with_overlay(codepoints, nil), do: longest_match(codepoints)

  def longest_match_with_overlay([cp | rest] = _codepoints, overlay) when is_map(overlay) do
    # Check overlay contractions first (try longest possible)
    overlay_max_len = overlay_max_contraction_length(cp, overlay)

    overlay_result =
      if overlay_max_len > 0 do
        available = [cp | Enum.take(rest, overlay_max_len - 1)]

        overlay_max_len..1//-1
        |> Enum.reduce_while(nil, fn len, _acc ->
          if len <= length(available) do
            candidate = Enum.take(available, len)
            key = Parser.codepoints_to_key(candidate)

            case Map.get(overlay, key) do
              nil ->
                {:cont, nil}

              elements ->
                remaining = Enum.drop([cp | rest], len)
                {:halt, {candidate, elements, remaining}}
            end
          else
            {:cont, nil}
          end
        end)
      else
        nil
      end

    case overlay_result do
      nil ->
        # No overlay match, fall back to root table
        longest_match([cp | rest])

      match ->
        match
    end
  end

  def longest_match_with_overlay([], _overlay), do: :done

  # Find the maximum contraction length in the overlay starting with cp.
  # Overlay keys are integers (single CP) or tuples (contractions).
  defp overlay_max_contraction_length(cp, overlay) do
    overlay
    |> Map.keys()
    |> Enum.reduce(0, fn
      ^cp, acc -> max(acc, 1)
      key, acc when is_tuple(key) and elem(key, 0) == cp -> max(acc, tuple_size(key))
      _, acc -> acc
    end)
  end

  # GenServer

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl true
  def init(_options) do
    if nif_enabled?() do
      {:ok, %{loaded: false}}
    else
      {:ok, %{loaded: false}, {:continue, :load}}
    end
  end

  @impl true
  def handle_continue(:load, state) do
    load_table()
    {:noreply, %{state | loaded: true}}
  end

  @impl true
  def handle_call(:load, _from, %{loaded: true} = state) do
    {:reply, :ok, state}
  end

  def handle_call(:load, _from, %{loaded: false} = state) do
    load_table()
    {:reply, :ok, %{state | loaded: true}}
  end

  defp nif_enabled? do
    System.get_env("CLDR_COLLATION_NIF") == "true" or
      Application.get_env(:ex_cldr_collation, :nif, false) == true
  end

  defp load_table do
    fractional_path = data_path(@fractional_keys)
    %{entries: all_entries} = Parser.parse(fractional_path)

    # Build contraction starters map.
    # Keys are now integers (single CP) or tuples (contractions).
    contractions =
      Enum.reduce(all_entries, %{}, fn {key, _elements}, acc ->
        case key do
          cp when is_integer(cp) ->
            acc

          tuple when is_tuple(tuple) ->
            first = elem(tuple, 0)
            len = tuple_size(tuple)
            existing = Map.get(acc, first, MapSet.new())
            Map.put(acc, first, MapSet.put(existing, len))
        end
      end)

    contractions =
      Map.new(contractions, fn {cp, lengths} -> {cp, MapSet.to_list(lengths)} end)

    # Store atomically in persistent_term
    :persistent_term.put(@table_name, all_entries)
    :persistent_term.put(@contractions_table, contractions)

    # Build fast Latin lookup table
    Cldr.Collation.FastLatin.build()
  end

  defp data_path(filename) do
    case :code.priv_dir(:cldr_collation) do
      {:error, :bad_name} ->
        Path.join([File.cwd!(), "priv", filename])

      priv_dir ->
        Path.join(priv_dir, filename)
    end
  end
end
