defmodule Cldr.Collation.Sensitive do
  @moduledoc """
  Compare two string using the UCA
  in a case-sensitive manner
  """

  @sensitive 0

  def compare(a, b) do
    Cldr.Collation.compare(a, b, @sensitive)
  end

end