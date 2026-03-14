defmodule Cldr.Collation.Nif do
  @moduledoc """
  Optional NIF-based collation using ICU's C library.

  This module provides high-performance Unicode collation by wrapping ICU4C
  via a Native Interface Function (NIF). It supports the CLDR root collation
  (DUCET) with case-sensitive and case-insensitive comparison modes.

  The NIF is opt-in and requires:

  1. ICU system libraries installed (`libicu` or `icucore` on macOS)
  2. The `elixir_make` dependency
  3. Compilation with `CLDR_COLLATION_NIF=true mix compile`

  If the NIF is not available, `available?/0` returns `false` and the
  pure Elixir implementation is used automatically.
  """

  @on_load :init

  @sensitive 0
  @insensitive 1

  @doc false
  def init do
    path = :code.priv_dir(:cldr_collation) ++ ~c"/ucol"

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
    function_exported?(__MODULE__, :cmp, 3) and
      match?({:ok, _}, nif_loaded?())
  end

  @doc false
  defp nif_loaded? do
    try do
      # If NIF is loaded, cmp/3 will be replaced by the native implementation.
      # Calling with empty strings is a lightweight probe.
      cmp("", "", @insensitive)
      {:ok, true}
    rescue
      _ -> {:error, :not_loaded}
    catch
      :exit, :nif_library_not_loaded -> {:error, :not_loaded}
    end
  end

  @doc """
  Compare two strings using the ICU NIF collator.

  ### Arguments

  * `string_a` - the first string to compare
  * `string_b` - the second string to compare
  * `casing` - `:sensitive` for case-sensitive or `:insensitive` for case-insensitive comparison

  ### Returns

  * `:lt` if `string_a` sorts before `string_b`
  * `:eq` if `string_a` and `string_b` are collation-equal
  * `:gt` if `string_a` sorts after `string_b`

  """
  @spec nif_compare(String.t(), String.t(), :sensitive | :insensitive) :: :lt | :eq | :gt
  def nif_compare(string_a, string_b, casing) do
    casing_flag =
      case casing do
        :insensitive -> @insensitive
        :sensitive -> @sensitive
      end

    case cmp(string_a, string_b, casing_flag) do
      1 -> :gt
      0 -> :eq
      -1 -> :lt
    end
  end

  @dialyzer {:no_return, cmp: 3}
  @doc false
  def cmp(_a, _b, _casing) do
    :erlang.nif_error(:nif_library_not_loaded)
  end
end
