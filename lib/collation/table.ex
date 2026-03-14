defmodule Collation.Table do
  @moduledoc """
  ETS-backed collation element table.

  Stores the CLDR allkeys table for fast concurrent lookups.
  Handles both single codepoint mappings and contractions (multi-codepoint sequences).
  """

  use GenServer

  alias Collation.Table.Parser

  @table_name :collation_table
  @contractions_table :collation_contractions

  # Public API

  @doc """
  Ensure the collation table is loaded into ETS.

  Loads the `allkeys_CLDR.txt` and `FractionalUCA.txt` data files on first call.
  Subsequent calls are no-ops.

  ### Returns

  * `:ok` - the table is loaded and ready for lookups

  ### Examples

      iex> Collation.Table.ensure_loaded()
      :ok
  """
  def ensure_loaded do
    case :ets.whereis(@table_name) do
      :undefined -> GenServer.call(__MODULE__, :load, :infinity)
      _ref -> :ok
    end
  end

  @doc """
  Look up collation elements for a codepoint or codepoint sequence.

  ### Arguments

  * `codepoint` - a single integer codepoint, or a list of integer codepoints (contraction)

  ### Returns

  * `{:ok, [%Collation.Element{}]}` - the collation elements for the entry
  * `:unmapped` - no entry found in the table

  ### Examples

      iex> Collation.Table.ensure_loaded()
      iex> {:ok, elements} = Collation.Table.lookup(0x0041)
      iex> hd(elements).primary > 0
      true

      iex> Collation.Table.ensure_loaded()
      iex> Collation.Table.lookup(0x10FFFF)
      :unmapped
  """
  def lookup(codepoint) when is_integer(codepoint) do
    case :ets.lookup(@table_name, [codepoint]) do
      [{_key, elements}] -> {:ok, elements}
      [] -> :unmapped
    end
  end

  def lookup(codepoints) when is_list(codepoints) do
    case :ets.lookup(@table_name, codepoints) do
      [{_key, elements}] -> {:ok, elements}
      [] -> :unmapped
    end
  end

  @doc """
  Check if a codepoint begins any multi-codepoint contraction.

  ### Arguments

  * `codepoint` - an integer codepoint to check

  ### Returns

  A list of contraction lengths that start with this codepoint, or `[]` if
  this codepoint does not begin any contractions.

  ### Examples

      iex> Collation.Table.ensure_loaded()
      iex> lengths = Collation.Table.contraction_starters(0x006C)
      iex> is_list(lengths)
      true
  """
  def contraction_starters(codepoint) do
    case :ets.lookup(@contractions_table, codepoint) do
      [{_key, lengths}] -> lengths
      [] -> []
    end
  end

  @doc """
  Find the longest matching entry for the given codepoint sequence.

  Tries contractions from longest to shortest, falling back to a single
  codepoint lookup.

  ### Arguments

  * `codepoints` - a list of integer codepoints to match against

  ### Returns

  * `{matched_cps, elements, remaining_cps}` - a successful match with the
    matched codepoints, their collation elements, and the remaining unprocessed tail
  * `{:unmapped, codepoint, remaining_cps}` - the first codepoint has no table entry
  * `:done` - the input list is empty

  ### Examples

      iex> Collation.Table.ensure_loaded()
      iex> {matched, _elements, rest} = Collation.Table.longest_match([0x0041, 0x0042])
      iex> matched
      [65]
      iex> rest
      [66]
  """
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

  def longest_match([]), do: :done

  # GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{loaded: false}}
  end

  @impl true
  def handle_call(:load, _from, %{loaded: true} = state) do
    {:reply, :ok, state}
  end

  def handle_call(:load, _from, %{loaded: false} = state) do
    load_table()
    {:reply, :ok, %{state | loaded: true}}
  end

  defp load_table do
    table = :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])

    contractions =
      :ets.new(@contractions_table, [:named_table, :set, :public, read_concurrency: true])

    allkeys_path = data_path("allkeys_CLDR.txt")
    %{entries: entries} = Parser.parse(allkeys_path)

    # Supplement with entries from FractionalUCA.txt not in allkeys
    fractional_path = data_path("FractionalUCA.txt")

    all_entries =
      if File.exists?(fractional_path) do
        Parser.parse_fractional_supplement(fractional_path, entries)
      else
        entries
      end

    # Track contraction starters
    contraction_starters = %{}

    contraction_starters =
      Enum.reduce(all_entries, contraction_starters, fn {codepoints, elements}, acc ->
        :ets.insert(table, {codepoints, elements})

        case codepoints do
          [first | _] when length(codepoints) > 1 ->
            len = length(codepoints)
            existing = Map.get(acc, first, MapSet.new())
            Map.put(acc, first, MapSet.put(existing, len))

          _ ->
            acc
        end
      end)

    Enum.each(contraction_starters, fn {cp, lengths} ->
      :ets.insert(contractions, {cp, MapSet.to_list(lengths)})
    end)

    table
  end

  defp data_path(filename) do
    case :code.priv_dir(:collation) do
      {:error, :bad_name} ->
        Path.join([File.cwd!(), "priv", filename])

      priv_dir ->
        Path.join(priv_dir, filename)
    end
  end
end
