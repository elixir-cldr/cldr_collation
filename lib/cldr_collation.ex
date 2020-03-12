defmodule Cldr.Collation do
  @on_load :init
  @so_path './priv/ucol'

  def init do
    num_scheds = :erlang.system_info(:schedulers)
    :ok = :erlang.load_nif(@so_path, num_scheds)
  end

  @insensitive 1
  @sensitive 0

  def compare(a, b) do
    compare(a, b, @insensitive)
  end

  def compare(a, b, casing) when is_integer(casing) do
    nif_cmp(a, b, casing)
  end

  def compare(a, b, options) when is_list(options) do
    casing = casing_from_options(options)
    nif_cmp(a, b, casing)
  end

  defp nif_cmp(a, b, casing) do
    case cmp(a, b, casing) do
      1 -> :gt
      0 -> :eq
      -1 -> :lt
    end
  end

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
