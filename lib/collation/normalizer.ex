defmodule Collation.Normalizer do
  @moduledoc """
  Unicode NFD normalization for collation.
  Delegates to Erlang's :unicode module.
  """

  @doc "Normalize a string to NFD form."
  def nfd(string) when is_binary(string) do
    string
    |> :unicode.characters_to_nfd_binary()
    |> String.to_charlist()
    |> canonical_reorder()
    |> List.to_string()
  end

  @doc "Convert a string to a list of codepoints."
  def to_codepoints(string) when is_binary(string) do
    string
    |> String.to_charlist()
  end

  @doc "Normalize and convert to codepoints."
  def normalize_to_codepoints(string, normalize? \\ false) do
    string
    |> then(fn s -> if normalize?, do: nfd(s), else: s end)
    |> to_codepoints()
  end

  # Canonical reordering pass using CCC data from the unicode package.
  # Erlang's NFD may not have up-to-date CCC values for newer codepoints,
  # so we re-sort adjacent combining marks by CCC (bubble sort until stable).
  defp canonical_reorder(codepoints) do
    case reorder_pass(codepoints, false) do
      {result, true} -> canonical_reorder(result)
      {result, false} -> result
    end
  end

  defp reorder_pass([a, b | rest], swapped) do
    ccc_a = Unicode.CanonicalCombiningClass.combining_class(a) || 0
    ccc_b = Unicode.CanonicalCombiningClass.combining_class(b) || 0

    if ccc_a > ccc_b and ccc_b > 0 do
      {tail, s} = reorder_pass([a | rest], true)
      {[b | tail], s}
    else
      {tail, s} = reorder_pass([b | rest], swapped)
      {[a | tail], s}
    end
  end

  defp reorder_pass([cp], swapped), do: {[cp], swapped}
  defp reorder_pass([], swapped), do: {[], swapped}
end
