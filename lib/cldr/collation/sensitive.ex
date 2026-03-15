defmodule Cldr.Collation.Sensitive do
  @moduledoc """
  Case-sensitive string comparator for use with `Enum.sort/2`.

  Implements the `compare/2` callback so this module can be passed directly
  to `Enum.sort/2` as a comparator:

      Enum.sort(strings, Cldr.Collation.Sensitive)

  Uses the NIF backend when available for maximum performance, otherwise
  falls back to the pure Elixir implementation at tertiary strength.

  """

  @doc """
  Compare two strings in a case-sensitive manner.

  ### Arguments

  * `string_a` - the first string to compare
  * `string_b` - the second string to compare

  ### Returns

  * `:lt` if `string_a` sorts before `string_b`
  * `:eq` if `string_a` and `string_b` are collation-equal
  * `:gt` if `string_a` sorts after `string_b`

  ### Examples

      iex> Cldr.Collation.Sensitive.compare("a", "A")
      :lt

      iex> Cldr.Collation.Sensitive.compare("b", "a")
      :gt

  """
  @spec compare(String.t(), String.t()) :: :lt | :eq | :gt
  def compare(string_a, string_b) do
    if Cldr.Collation.Nif.available?() do
      Cldr.Collation.Nif.nif_compare(string_a, string_b, %Cldr.Collation.Options{})
    else
      Cldr.Collation.compare(string_a, string_b, backend: :elixir)
    end
  end
end
