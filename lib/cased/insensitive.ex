defmodule Cldr.Collation.Insensitive do
  @moduledoc """
  Compare two strings using the UCA
  in a case-insensitive manner

  """

  @insensitive 1
  @dialyzer {:no_return, compare: 2}

  def compare(a, b) do
    Cldr.Collation.nif_compare(a, b, @insensitive)
  end

end