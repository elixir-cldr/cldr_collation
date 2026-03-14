defmodule Cldr.Collation.Nif do
  @moduledoc """
  Optional NIF-based collation using ICU's C library.

  This module provides high-performance Unicode collation by wrapping ICU4C
  via a Native Interface Function (NIF). It supports all ICU-configurable
  collation attributes: strength, backwards (French), alternate handling,
  case first, case level, normalization, numeric collation, and script
  reordering.

  The NIF is opt-in and requires:

  1. ICU system libraries installed (`libicu` or `icucore` on macOS)
  2. The `elixir_make` dependency
  3. Compilation with `CLDR_COLLATION_NIF=true mix compile`

  If the NIF is not available, `available?/0` returns `false` and the
  pure Elixir implementation is used automatically.
  """

  alias Cldr.Collation.Options

  @on_load :init

  # Sentinel value meaning "use ICU default / no change"
  @opt_default -1

  # ICU UColAttributeValue enum values
  @ucol_primary 0
  @ucol_secondary 1
  @ucol_quaternary 3
  @ucol_identical 15

  @ucol_on 17

  @ucol_shifted 20

  @ucol_lower_first 24
  @ucol_upper_first 25

  # ICU UScriptCode values (from uscript.h) and UColReorderCode values (from ucol.h)
  @script_codes %{
    # Special reorder codes (UColReorderCode)
    :space =>  0x1000,
    :punct =>  0x1001,
    :punctuation =>  0x1001,
    :symbol =>  0x1002,
    :currency =>  0x1003,
    :digit =>  0x1004,
    :others =>  0,
    :Zzzz =>  0,

    # Common script codes (UScriptCode)
    :Arab => 2,
    :Armn => 3,
    :Beng => 4,
    :Cyrl => 8,
    :Deva => 10,
    :Ethi => 11,
    :Geor => 12,
    :Grek => 14,
    :Gujr => 15,
    :Guru => 16,
    :Hani => 17,
    :Hang => 18,
    :Hebr => 19,
    :Hira => 20,
    :Knda => 21,
    :Kana => 22,
    :Khmr => 23,
    :Laoo => 24,
    :Latn => 25,
    :Mlym => 26,
    :Mong => 27,
    :Mymr => 28,
    :Orya => 31,
    :Sinh => 33,
    :Taml => 35,
    :Telu => 36,
    :Thai => 38,
    :Tibt => 39
  }

  @doc false
  def init do
    path = :code.priv_dir(:ex_cldr_collation) ++ ~c"/ucol"

    case :erlang.load_nif(path, :erlang.system_info(:schedulers)) do
      :ok -> :ok
      {:error, _reason} -> :ok
    end
  end

  @doc """
  Returns whether the NIF collation backend is available.

  ### Returns

  * `true` if the NIF shared library was loaded successfully
  * `false` if the NIF is not compiled or ICU libraries are missing

  ### Examples

      iex> is_boolean(Cldr.Collation.Nif.available?())
      true

  """
  @spec available?() :: boolean()
  def available? do
    function_exported?(__MODULE__, :cmp, 10) and
      match?({:ok, _}, nif_loaded?())
  end

  @doc false
  defp nif_loaded? do
    try do
      # If NIF is loaded, cmp/10 will be replaced by the native implementation.
      # Calling with empty strings and all defaults is a lightweight probe.
      cmp(
        "", "",
        @opt_default, @opt_default, @opt_default, @opt_default,
        @opt_default, @opt_default, @opt_default, <<>>
      )

      {:ok, true}
    rescue
      _ -> {:error, :not_loaded}
    catch
      :exit, :nif_library_not_loaded -> {:error, :not_loaded}
    end
  end

  @doc """
  Compare two strings using the ICU NIF collator with full option support.

  ### Arguments

  * `string_a` - the first string to compare
  * `string_b` - the second string to compare
  * `options` - a `%Cldr.Collation.Options{}` struct

  ### Returns

  * `:lt` if `string_a` sorts before `string_b`
  * `:eq` if `string_a` and `string_b` are collation-equal
  * `:gt` if `string_a` sorts after `string_b`

  """
  @spec nif_compare(String.t(), String.t(), Options.t()) :: :lt | :eq | :gt
  def nif_compare(string_a, string_b, %Options{} = options) do
    {strength, backwards, alternate, case_first, case_level, normalization, numeric,
     reorder_bin} = options_to_nif_args(options)

    case cmp(
           string_a, string_b,
           strength, backwards, alternate, case_first,
           case_level, normalization, numeric, reorder_bin
         ) do
      1 -> :gt
      0 -> :eq
      -1 -> :lt
    end
  end

  @doc false
  def options_to_nif_args(%Options{} = options) do
    strength = encode_strength(options.strength)
    backwards = encode_bool(options.backwards)
    alternate = encode_alternate(options.alternate)
    case_first = encode_case_first(options.case_first)
    case_level = encode_bool(options.case_level)
    normalization = encode_bool(options.normalization)
    numeric = encode_bool(options.numeric)
    reorder_bin = encode_reorder_codes(options.reorder)

    {strength, backwards, alternate, case_first, case_level, normalization, numeric, reorder_bin}
  end

  @doc """
  Returns whether all reorder codes in the list can be mapped to ICU values.

  ### Arguments

  * `reorder_codes` - a list of script code atoms (e.g., `[:Grek, :Latn]`)

  ### Returns

  * `true` if all codes are recognized
  * `false` if any code is unrecognized

  ### Examples

      iex> Cldr.Collation.Nif.reorder_codes_supported?([:Grek, :Latn])
      true

      iex> Cldr.Collation.Nif.reorder_codes_supported?([:Unknown])
      false

      iex> Cldr.Collation.Nif.reorder_codes_supported?([])
      true

  """
  @spec reorder_codes_supported?([atom()]) :: boolean()
  def reorder_codes_supported?(reorder_codes) do
    Enum.all?(reorder_codes, &Map.has_key?(@script_codes, &1))
  end

  # Encode strength to ICU enum value.
  # Tertiary is the ICU default, so we use the sentinel to avoid unnecessary setAttribute.
  defp encode_strength(:tertiary), do: @opt_default
  defp encode_strength(:primary), do: @ucol_primary
  defp encode_strength(:secondary), do: @ucol_secondary
  defp encode_strength(:quaternary), do: @ucol_quaternary
  defp encode_strength(:identical), do: @ucol_identical

  # Encode boolean options. false is the ICU default for all boolean attributes.
  defp encode_bool(false), do: @opt_default
  defp encode_bool(true), do: @ucol_on

  # Encode alternate handling. :non_ignorable is the ICU default.
  defp encode_alternate(:non_ignorable), do: @opt_default
  defp encode_alternate(:shifted), do: @ucol_shifted

  # Encode case_first. false (off) is the ICU default.
  defp encode_case_first(false), do: @opt_default
  defp encode_case_first(:upper), do: @ucol_upper_first
  defp encode_case_first(:lower), do: @ucol_lower_first

  # Encode reorder codes as a binary of packed big-endian int32 values.
  # Returns <<>> for empty list (no reordering).
  defp encode_reorder_codes([]), do: <<>>

  defp encode_reorder_codes(codes) do
    codes
    |> Enum.map(&Map.fetch!(@script_codes, &1))
    |> Enum.reduce(<<>>, fn code, acc -> acc <> <<code::big-signed-32>> end)
  end

  @dialyzer {:no_return, cmp: 10}
  @doc false
  def cmp(_a, _b, _strength, _backwards, _alternate, _case_first, _case_level, _normalization, _numeric, _reorder_bin) do
    :erlang.nif_error(:nif_library_not_loaded)
  end
end
