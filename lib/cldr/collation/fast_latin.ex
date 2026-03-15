defmodule Cldr.Collation.FastLatin do
  @moduledoc """
  Fast lookup table for Basic Latin and Latin Extended-A codepoints.

  Provides O(1) collation element lookup for codepoints U+0000..U+017F
  by pre-computing a tuple indexed by codepoint value. This bypasses
  the full contraction-checking path in `Cldr.Collation.Table` for the
  most commonly encountered characters.

  Codepoints that are contraction starters (e.g., `L` and `l` for Catalan
  l·l) or combining marks (CCC > 0) are excluded from the fast table and
  fall back to the normal lookup path.

  """

  @table_name :collation_fast_latin
  @latin_limit 0x0180

  @doc """
  Build the fast Latin lookup table from the loaded collation table.

  Reads the collation table and contraction starters from `:persistent_term`,
  and constructs a tuple of `@latin_limit` entries. Each entry is either a
  list of collation element tuples (for direct lookup) or `nil` (indicating
  the codepoint must use the full lookup path).

  Called automatically during table loading.

  ### Returns

  * `:ok`.

  """
  def build do
    table = :persistent_term.get(:collation_table)
    contractions = :persistent_term.get(:collation_contractions)

    entries =
      for cp <- 0..(@latin_limit - 1) do
        cond do
          # Contraction starters must use the full path
          Map.has_key?(contractions, cp) ->
            nil

          # Combining marks (CCC > 0) must use the full path for
          # discontiguous contraction matching
          combining_mark?(cp) ->
            nil

          true ->
            Map.get(table, cp)
        end
      end

    tuple = List.to_tuple(entries)
    :persistent_term.put(@table_name, tuple)
    :ok
  end

  @doc """
  Look up collation elements for a Latin codepoint.

  ### Arguments

  * `cp` - an integer codepoint less than `0x0180`.

  ### Returns

  * A list of collation element tuples — the codepoint has a direct mapping.
  * `nil` — the codepoint is a contraction starter, combining mark, or unmapped;.
    use the full lookup path

  ### Examples

      iex> Cldr.Collation.FastLatin.lookup(?a)
      [{9196, 32, 2, false}]

      iex> Cldr.Collation.FastLatin.lookup(?l)
      nil

  """
  def lookup(cp) when cp < @latin_limit do
    elem(:persistent_term.get(@table_name), cp)
  end

  # Characters with canonical combining class > 0 in the Basic Latin
  # and Latin Extended-A range. These are the combining diacritical
  # marks that appear in U+0000..U+017F after NFD decomposition.
  defp combining_mark?(cp) do
    ccc = Unicode.CanonicalCombiningClass.combining_class(cp)
    ccc != nil and ccc > 0
  end
end
