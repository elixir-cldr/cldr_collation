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

  @doc "Ensure the table is loaded. Idempotent."
  def ensure_loaded do
    case :ets.whereis(@table_name) do
      :undefined -> GenServer.call(__MODULE__, :load, :infinity)
      _ref -> :ok
    end
  end

  @doc """
  Look up collation elements for a single codepoint or codepoint sequence (contraction).
  Returns `{:ok, [%Element{}]}` or `:unmapped`.
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
  Check if a codepoint begins any contraction.
  Returns the set of contraction lengths starting with this codepoint.
  """
  def contraction_starters(codepoint) do
    case :ets.lookup(@contractions_table, codepoint) do
      [{_key, lengths}] -> lengths
      [] -> []
    end
  end

  @doc """
  Find the longest matching entry for the given codepoint sequence.

  Returns `{matched_cps, elements, remaining_cps}` where:
  - `matched_cps` is the list of codepoints that matched
  - `elements` is the list of CEs for the match
  - `remaining_cps` is the unprocessed tail

  If no match at all, returns `:unmapped` with the first codepoint.
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
    contractions = :ets.new(@contractions_table, [:named_table, :set, :public, read_concurrency: true])

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
