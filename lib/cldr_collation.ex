defmodule Cldr.Collation do
  @on_load :init

  @so_path './priv/ucol'
  def init do
    num_scheds = :erlang.system_info(:schedulers)
    :ok = :erlang.load_nif(@so_path, num_scheds)
  end

  def cmp(a, b, options \\ []) do
    casing = casing_from_options(options)
    ucol(a, b, casing)
  end

  def compare(a, b, options \\ []) do
    casing = casing_from_options(options)
    case cmp(a, b, casing) do
      1 -> :gt
      0 -> :eq
      -1 -> :lt
    end
  end

  def ucol(_a, _b, _casing) do
    exit(:nif_library_not_loaded)
  end

  defp casing_from_options(options) do
    case Keyword.get(options, :casing, :insensitive) do
      :insensitive -> 1
      :sensitive -> 0
      _ -> 1
    end
  end
end
