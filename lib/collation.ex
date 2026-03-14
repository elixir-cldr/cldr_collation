defmodule Collation do
  @moduledoc """
  CLDR Collation Algorithm implementation for Elixir.

  Implements the Unicode Collation Algorithm (UCA) as extended by CLDR,
  based on the ICU Collation Service architecture.

  ## Usage

      # Compare two strings
      Collation.compare("café", "cafe")
      #=> :gt

      # Sort a list of strings
      Collation.sort(["café", "cafe", "Cafe"])
      #=> ["cafe", "Cafe", "café"]

      # Generate a sort key
      Collation.sort_key("hello")
      #=> <<...binary sort key...>>

      # With options
      Collation.compare("a", "A", strength: :secondary)
      #=> :eq

      # From BCP47 locale
      Collation.compare("a", "A", locale: "en-u-ks-level2")
      #=> :eq

  ## Collation Options

  All BCP47 -u- extension collation keys are supported:

  - `strength` - `:primary`, `:secondary`, `:tertiary` (default), `:quaternary`, `:identical`
  - `alternate` - `:non_ignorable` (default), `:shifted`
  - `backwards` - `false` (default), `true` - reverse secondary weights (French)
  - `normalization` - `false` (default), `true` - NFD normalize input
  - `case_level` - `false` (default), `true` - insert case-only level
  - `case_first` - `false` (default), `:upper`, `:lower`
  - `numeric` - `false` (default), `true` - numeric string comparison
  - `reorder` - `[]` (default), list of script codes
  - `max_variable` - `:punct` (default), `:space`, `:symbol`, `:currency`
  """

  alias Collation.{Element, ImplicitWeights, Normalizer, Options, Reorder, SortKey, Table, Variable}

  @doc """
  Compare two strings using the CLDR collation algorithm.

  Returns `:lt`, `:eq`, or `:gt`.

  ## Options

  See module documentation for available options. Can also pass `locale:` to
  parse options from a BCP47 locale string.
  """
  def compare(string_a, string_b, opts \\ []) do
    options = resolve_options(opts)
    key_a = sort_key(string_a, options)
    key_b = sort_key(string_b, options)

    cond do
      key_a < key_b -> :lt
      key_a > key_b -> :gt
      true -> :eq
    end
  end

  @doc """
  Generate a binary sort key for the given string.

  Sort keys can be compared directly with `<`, `>`, `==` for ordering.
  This is efficient when the same strings need to be compared multiple times.

  ## Options

  Accepts a keyword list or a `%Collation.Options{}` struct.
  """
  def sort_key(input, opts \\ [])

  def sort_key(input, opts) when is_list(opts) do
    sort_key(input, resolve_options(opts))
  end

  def sort_key(string, %Options{} = options) when is_binary(string) do
    ensure_loaded()
    codepoints = Normalizer.normalize_to_codepoints(string, options.normalization)
    build_sort_key(codepoints, options, string)
  end

  def sort_key(codepoints, %Options{} = options) when is_list(codepoints) do
    ensure_loaded()

    codepoints =
      if options.normalization do
        codepoints
        |> List.to_string()
        |> Normalizer.normalize_to_codepoints(true)
      else
        codepoints
      end

    build_sort_key(codepoints, options, nil)
  end

  defp build_sort_key(codepoints, options, original_string) do
    elements = produce_collation_elements(codepoints, options)

    max_var_primary = Options.max_variable_primary(options)
    processed = Variable.process(elements, options.alternate, max_var_primary)

    processed =
      case Reorder.build_mapping(options.reorder) do
        nil ->
          processed

        mapping_fn ->
          Enum.map(processed, fn {%Element{} = elem, q} ->
            {%Element{elem | primary: mapping_fn.(elem.primary)}, q}
          end)
      end

    SortKey.build(processed, options, original_string)
  end

  @doc """
  Sort a list of strings using the CLDR collation algorithm.

  ## Options

  See module documentation for available options.
  """
  def sort(strings, opts \\ []) do
    options = resolve_options(opts)

    strings
    |> Enum.map(fn s -> {sort_key(s, options), s} end)
    |> Enum.sort_by(fn {key, _s} -> key end)
    |> Enum.map(fn {_key, s} -> s end)
  end

  @doc """
  Ensure the collation tables are loaded. Called automatically by other functions.
  """
  def ensure_loaded do
    Table.ensure_loaded()
  end

  # Internal: produce collation elements from codepoints

  defp produce_collation_elements(codepoints, options) do
    if options.numeric do
      produce_with_numeric(codepoints, options)
    else
      produce_standard(codepoints)
    end
  end

  defp produce_standard(codepoints) do
    do_produce(codepoints, [])
  end

  defp do_produce([], acc), do: Enum.reverse(acc) |> List.flatten()

  defp do_produce(codepoints, acc) do
    case Table.longest_match(codepoints) do
      {matched, elements, remaining} when is_list(elements) ->
        # After matching, check for discontiguous contractions with following
        # combining marks (UCA S2.1.1)
        {final_elements, final_remaining} =
          try_discontiguous_match(matched, elements, remaining)

        do_produce(final_remaining, [final_elements | acc])

      {:unmapped, cp, remaining} ->
        elements = resolve_unmapped(cp)
        # Also check for discontiguous contractions starting from unmapped char
        {final_elements, final_remaining} =
          try_discontiguous_match([cp], elements, remaining)

        do_produce(final_remaining, [final_elements | acc])

      :done ->
        Enum.reverse(acc) |> List.flatten()
    end
  end

  # UCA S2.1.1: Discontiguous contraction matching
  # After matching a starter S, check if any following combining marks
  # can form a contraction with S, skipping blocked combining marks.
  #
  # A combining mark C at position i is "blocked" if there exists
  # another combining mark B between S and C such that ccc(B) >= ccc(C).
  defp try_discontiguous_match(matched_cps, elements, remaining) do
    case remaining do
      [] ->
        {elements, remaining}

      _ ->
        # Collect following combining marks
        {combiners, rest} = collect_combining(remaining, [])

        if combiners == [] do
          {elements, remaining}
        else
          # Try to extend the match with unblocked combining marks
          {new_elements, _consumed, unconsumed} =
            extend_with_combiners(matched_cps, elements, combiners)

          # Reconstruct remaining: unconsumed combiners + rest
          new_remaining = unconsumed ++ rest
          {new_elements, new_remaining}
        end
    end
  end

  # Collect consecutive combining characters (ccc > 0)
  defp collect_combining([cp | rest], acc) do
    ccc = combining_class(cp)

    if ccc > 0 do
      collect_combining(rest, [{cp, ccc} | acc])
    else
      {Enum.reverse(acc), [cp | rest]}
    end
  end

  defp collect_combining([], acc), do: {Enum.reverse(acc), []}

  # Try to match the base sequence + each unblocked combining mark
  defp extend_with_combiners(base_cps, base_elements, combiners) do
    {final_elements, consumed_set, _last_ccc, _current_base} =
      Enum.reduce(combiners, {base_elements, MapSet.new(), 0, base_cps}, fn {cp, ccc}, {elems, consumed, last_ccc, current_base} ->
        # Check if this combining mark is blocked
        if ccc > 0 and (last_ccc == 0 or ccc > last_ccc) do
          # Not blocked - try to extend the match
          candidate = current_base ++ [cp]

          case Table.lookup(candidate) do
            {:ok, new_elements} ->
              {new_elements, MapSet.put(consumed, cp), ccc, candidate}

            :unmapped ->
              {elems, consumed, ccc, current_base}
          end
        else
          # Blocked - skip
          {elems, consumed, last_ccc, current_base}
        end
      end)

    unconsumed =
      Enum.reject(combiners, fn {cp, _ccc} -> MapSet.member?(consumed_set, cp) end)
      |> Enum.map(fn {cp, _ccc} -> cp end)

    {final_elements, consumed_set, unconsumed}
  end

  # Get the canonical combining class for a codepoint
  defp combining_class(cp) do
    Unicode.CanonicalCombiningClass.combining_class(cp) || 0
  end

  defp produce_with_numeric(codepoints, _options) do
    pairs = collect_ce_pairs(codepoints, [])
    Collation.Numeric.process_elements(pairs)
  end

  defp collect_ce_pairs([], acc), do: Enum.reverse(acc)

  defp collect_ce_pairs(codepoints, acc) do
    case Table.longest_match(codepoints) do
      {matched, elements, remaining} when is_list(elements) ->
        collect_ce_pairs(remaining, [{matched, elements} | acc])

      {:unmapped, cp, remaining} ->
        elements = resolve_unmapped(cp)
        collect_ce_pairs(remaining, [{[cp], elements} | acc])

      :done ->
        Enum.reverse(acc)
    end
  end

  defp resolve_unmapped(cp) do
    case ImplicitWeights.compute(cp) do
      {:hangul_decompose, jamo} ->
        Enum.flat_map(jamo, fn j ->
          case Table.lookup(j) do
            {:ok, elements} -> elements
            :unmapped -> ImplicitWeights.compute(j)
          end
        end)

      elements when is_list(elements) ->
        elements
    end
  end

  defp resolve_options(opts) when is_list(opts) do
    case Keyword.get(opts, :locale) do
      nil -> Options.new(opts)
      locale -> Options.from_locale(locale) |> struct(Keyword.delete(opts, :locale))
    end
  end

  defp resolve_options(%Options{} = opts), do: opts
end
