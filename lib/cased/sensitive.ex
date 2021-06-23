defmodule Cldr.Collation.Sensitive do
  @moduledoc """
  Compare two strings using the UCA
  in a case-sensitive manner

  """

  @sensitive 0
  @dialyzer {:no_return, compare: 2}

  def compare(a, b) do
    Cldr.Collation.nif_compare(a, b, @sensitive)
  end

end