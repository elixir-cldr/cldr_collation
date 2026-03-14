defmodule Collation.Normalizer do
  @moduledoc """
  Unicode NFD normalization for collation.
  Delegates to Erlang's :unicode module.
  """

  @doc "Normalize a string to NFD form."
  def nfd(string) when is_binary(string) do
    :unicode.characters_to_nfd_binary(string)
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
end
