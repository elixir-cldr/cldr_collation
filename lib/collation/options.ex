defmodule Collation.Options do
  @moduledoc """
  Collation options corresponding to BCP47 -u- extension keys.

  Supports both Elixir keyword list construction and parsing from
  BCP47 locale strings (e.g., "en-u-co-phonebk-ks-level2").
  """

  defstruct strength: :tertiary,
            alternate: :non_ignorable,
            backwards: false,
            normalization: false,
            case_level: false,
            case_first: false,
            numeric: false,
            reorder: [],
            max_variable: :punct,
            type: :standard

  @type strength :: :primary | :secondary | :tertiary | :quaternary | :identical
  @type alternate :: :non_ignorable | :shifted
  @type case_first_opt :: :upper | :lower | false
  @type max_variable :: :space | :punct | :symbol | :currency

  @type t :: %__MODULE__{
          strength: strength(),
          alternate: alternate(),
          backwards: boolean(),
          normalization: boolean(),
          case_level: boolean(),
          case_first: case_first_opt(),
          numeric: boolean(),
          reorder: [String.t()],
          max_variable: max_variable(),
          type: atom()
        }

  @doc "Create options from a keyword list."
  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end

  @doc """
  Parse collation options from a BCP47 locale string with -u- extension.

  Example: "en-u-co-phonebk-ks-level2-ka-shifted"
  """
  def from_locale(locale) when is_binary(locale) do
    case extract_u_extension(locale) do
      nil -> new()
      pairs -> from_u_pairs(pairs)
    end
  end

  defp extract_u_extension(locale) do
    parts = String.split(locale, "-")
    # Find the -u- extension
    case Enum.find_index(parts, &(&1 == "u")) do
      nil ->
        nil

      idx ->
        # Collect key-value pairs after -u- until next extension or end
        parts
        |> Enum.drop(idx + 1)
        |> collect_pairs([])
    end
  end

  defp collect_pairs([], acc), do: Enum.reverse(acc)

  # Stop at next extension singleton (single letter that's not a value)
  defp collect_pairs([<<c::utf8>> | _rest], acc)
       when c in ?a..?z and c != ?u do
    Enum.reverse(acc)
  end

  defp collect_pairs([key, value | rest], acc) when byte_size(key) == 2 do
    collect_pairs(rest, [{key, value} | acc])
  end

  defp collect_pairs([key | rest], acc) when byte_size(key) == 2 do
    # Key with boolean true implied
    collect_pairs(rest, [{key, "true"} | acc])
  end

  defp collect_pairs([value | rest], acc) do
    # Multi-value continuation (e.g., kr-latn-grek)
    # Append to previous pair's value
    case acc do
      [{key, prev_val} | acc_rest] ->
        collect_pairs(rest, [{key, prev_val <> "-" <> value} | acc_rest])

      _ ->
        collect_pairs(rest, acc)
    end
  end

  defp from_u_pairs(pairs) do
    Enum.reduce(pairs, new(), fn {key, value}, opts ->
      case key do
        "co" -> %{opts | type: parse_type(value)}
        "ks" -> %{opts | strength: parse_strength(value)}
        "ka" -> %{opts | alternate: parse_alternate(value)}
        "kb" -> %{opts | backwards: parse_bool(value)}
        "kk" -> %{opts | normalization: parse_bool(value)}
        "kc" -> %{opts | case_level: parse_bool(value)}
        "kf" -> %{opts | case_first: parse_case_first(value)}
        "kn" -> %{opts | numeric: parse_bool(value)}
        "kr" -> %{opts | reorder: String.split(value, "-")}
        "kv" -> %{opts | max_variable: parse_max_variable(value)}
        _ -> opts
      end
    end)
  end

  defp parse_strength("level1"), do: :primary
  defp parse_strength("level2"), do: :secondary
  defp parse_strength("level3"), do: :tertiary
  defp parse_strength("level4"), do: :quaternary
  defp parse_strength("identic"), do: :identical
  defp parse_strength(_), do: :tertiary

  defp parse_alternate("noignore"), do: :non_ignorable
  defp parse_alternate("shifted"), do: :shifted
  defp parse_alternate(_), do: :non_ignorable

  defp parse_bool("true"), do: true
  defp parse_bool("false"), do: false
  defp parse_bool(_), do: false

  defp parse_case_first("upper"), do: :upper
  defp parse_case_first("lower"), do: :lower
  defp parse_case_first("false"), do: false
  defp parse_case_first(_), do: false

  defp parse_max_variable("space"), do: :space
  defp parse_max_variable("punct"), do: :punct
  defp parse_max_variable("symbol"), do: :symbol
  defp parse_max_variable("currency"), do: :currency
  defp parse_max_variable(_), do: :punct

  defp parse_type("standard"), do: :standard
  defp parse_type("search"), do: :search
  defp parse_type("phonebk"), do: :phonebook
  defp parse_type("pinyin"), do: :pinyin
  defp parse_type("stroke"), do: :stroke
  defp parse_type("unihan"), do: :unihan
  defp parse_type("zhuyin"), do: :zhuyin
  defp parse_type("searchjl"), do: :searchjl
  defp parse_type("eor"), do: :eor
  defp parse_type(other), do: String.to_atom(other)

  @doc """
  Returns the maximum primary weight that counts as "variable"
  for the given max_variable setting.

  These boundaries come from the FractionalUCA.txt top_byte groupings:
  - space: primary weights in the SPACE group
  - punct: SPACE + PUNCTUATION groups
  - symbol: SPACE + PUNCTUATION + SYMBOL groups
  - currency: SPACE + PUNCTUATION + SYMBOL + CURRENCY groups
  """
  def max_variable_primary(%__MODULE__{max_variable: :space}), do: 0x0209
  def max_variable_primary(%__MODULE__{max_variable: :punct}), do: 0x0B61
  def max_variable_primary(%__MODULE__{max_variable: :symbol}), do: 0x0EE3
  def max_variable_primary(%__MODULE__{max_variable: :currency}), do: 0x0EFF
end
