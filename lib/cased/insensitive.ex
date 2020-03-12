defmodule Cldr.Collation.Insensitive do
  @moduledoc """
  Compare two string using the UCA
  in a case-insensitive manner
  """

  @insensitive 1

  def compare(a, b) do
    Cldr.Collation.compare(a, b, @insensitive)
  end

end