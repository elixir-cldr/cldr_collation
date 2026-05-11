defmodule Cldr.Collation.Insensitive do
  @moduledoc """
  Case-insensitive comparator for use with `Enum.sort/2` and `Enum.sort_by/3`.

  Implements the `compare/2` callback so this module can be passed directly
  to `Enum.sort/2` as a comparator:

      Enum.sort(strings, Cldr.Collation.Insensitive)

  When both arguments are binaries, comparison uses the NIF backend if
  available for maximum performance, otherwise the pure Elixir implementation
  at secondary strength (which ignores case distinctions).

  When either argument is **not** a binary — for example when used as the
  comparator inside `Enum.sort_by/3` with a multi-key sort function that
  returns mixed terms — `compare/2` falls back to Erlang term ordering
  (`<` / `>`). This keeps the comparator usable in the common case where
  most sort keys are booleans, atoms, integers, or tuples and only the
  last key is a string. Term ordering means: numbers compare numerically,
  atoms by atom order, tuples element-wise, etc.

  """

  @doc """
  Compare two terms in a case-insensitive manner when both are strings,
  otherwise by Erlang term order.

  ### Arguments

  * `a` - any term to compare.
  * `b` - any term to compare.

  ### Returns

  * `:lt` if `a` sorts before `b`.
  * `:eq` if `a` and `b` are equal (collation-equal for strings, term-equal
     for everything else).
  * `:gt` if `a` sorts after `b`.

  ### Examples

      iex> Cldr.Collation.Insensitive.compare("a", "A")
      :eq

      iex> Cldr.Collation.Insensitive.compare("b", "a")
      :gt

      iex> Cldr.Collation.Insensitive.compare(1, 2)
      :lt

      iex> Cldr.Collation.Insensitive.compare(true, false)
      :gt

      iex> Cldr.Collation.Insensitive.compare({:a, 1}, {:a, 2})
      :lt

  """
  @spec compare(term(), term()) :: :lt | :eq | :gt
  def compare(a, b) when is_binary(a) and is_binary(b) do
    if Cldr.Collation.Nif.available?() do
      Cldr.Collation.Nif.nif_compare(a, b, %Cldr.Collation.Options{strength: :secondary})
    else
      Cldr.Collation.compare(a, b, backend: :elixir, strength: :secondary)
    end
  end

  def compare(a, b) do
    cond do
      a < b -> :lt
      a > b -> :gt
      true -> :eq
    end
  end
end
