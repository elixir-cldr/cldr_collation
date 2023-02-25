defmodule Cldr.Collation do
  @moduledoc """
  Implements the [Unicode collation](http://www.unicode.org/reports/tr35/tr35-collation.html)
  rules based on the [CLDR root collation](http://www.unicode.org/reports/tr35/tr35-collation.html#Root_Collation)
  which in turn is based upon the [Unicode DUCET](https://www.unicode.org/reports/tr10/#Default_Unicode_Collation_Element_Table)
  table.

  """
  @on_load :init

  @type options :: [
    {:casing, :sensitive | :insensitive}
  ]

  @type comparison :: :lt | :eq | :gt

  def init do
    so_path = :code.priv_dir(:ex_cldr_collation) ++ '/ucol'
    num_scheds = :erlang.system_info(:schedulers)
    :erlang.load_nif(so_path, num_scheds)
  end

  @insensitive 1
  @sensitive 0

  @doc """
  Sorts a list of strings according to the
  [Unicode collation](http://www.unicode.org/reports/tr35/tr35-collation.html)
  rules with the [CLDR root collation](http://www.unicode.org/reports/tr35/tr35-collation.html#Root_Collation)
  which is based upon the [Unicode DUCET](https://www.unicode.org/reports/tr10/#Default_Unicode_Collation_Element_Table)
  table.

  This collation does not aim to provide precisely correct ordering
  for each language and script; tailoring would be required for correct
  language handling in almost all cases.

  The goal is instead to have all the other characters, those
  that are not tailored, show up in a reasonable order.

  ## Arguments

  * `strings` is an enumerable of type `t:String.t()`

  * `options` is a keyword list of options

  ## Options

  * `casing` is either `:sensitive` or `:insensitive`
    indicating if collation is to be case sensitive or not.
    The default is `:insensitive`

  ## Returns

  * An ordered list of `t:String.t()`

  ## Examples

      iex> Cldr.Collation.sort ["á", "b", "A"]
      ["á", "A", "b"]

      iex> Cldr.Collation.sort ["á", "b", "A"], casing: :sensitive
      ["A", "á", "b"]

  """
  @spec sort([String.t(), ...], options()) :: [String.t(), ...]

  @default_options [casing: :insensitive]
  def sort(list, options \\ @default_options) when is_list(options) do
    comparator =
      case Keyword.get(options, :casing, :insensitive) do
        :insensitive -> Cldr.Collation.Insensitive
        :sensitive -> Cldr.Collation.Sensitive
        other -> raise ArgumentError,
          """
          Unknown casing option #{inspect other}. Must be either :sensitive or :insensitive
          """
      end

    Enum.sort(list, comparator)
  end

  @doc """
  Compares two strings according to the
  [Unicode collation](http://www.unicode.org/reports/tr35/tr35-collation.html)
  rules with the [CLDR root collation](http://www.unicode.org/reports/tr35/tr35-collation.html#Root_Collation)
  which is based upon the [Unicode DUCET](https://www.unicode.org/reports/tr10/#Default_Unicode_Collation_Element_Table)
  table.

  ## Arguments

  * `string_1` is an a `t:String.t/0`

  * `string_2` is an a `t:String.t/0`

  * `options` is a keyword list of options

  ## Options

  * `:casing` is either `:sensitive` or `:insensitive`
    indicating if collation is to be case sensitive or not.
    The default is `:insensitive`.

  ## Returns

  * Either of `:lt`, `:eq` or `:gt` signifying if
    `string_1` is less than, equal to or greater than
    `string_2`.

  ## Examples

      iex> Cldr.Collation.compare "á", "A", casing: :sensitive
      :gt

      iex> Cldr.Collation.compare "á", "A", casing: :insensitive
      :eq

  """
  @spec compare(string_1 :: String.t(), string_2 :: String.t(), options()) :: comparison()

  @dialyzer {:no_return, compare: 3}
  @dialyzer {:no_return, compare: 2}
  def compare(string_1, string_2, options \\ @default_options)
      when is_binary(string_1) and is_binary(string_2) and is_list(options) do
    casing = casing_from_options(options)
    nif_compare(string_1, string_2, casing)
  end

  @doc false
  @dialyzer {:no_return, nif_compare: 3}
  def nif_compare(a, b, casing) do
    case cmp(a, b, casing) do
      1 -> :gt
      0 -> :eq
      -1 -> :lt
    end
  end

  @dialyzer {:no_return, cmp: 3}
  defp cmp(_a, _b, _casing) do
    exit(:nif_library_not_loaded)
  end

  defp casing_from_options(options) do
    case Keyword.get(options, :casing, :insensitive) do
      :insensitive -> @insensitive
      :sensitive -> @sensitive
      _ -> @insensitive
    end
  end
end
