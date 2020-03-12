defmodule CldrCollationTest do
  use ExUnit.Case
  doctest Cldr.Collation

  test "collation" do
    assert Cldr.Collation.compare("a", "A", casing: :insensitive) == :eq
    assert Cldr.Collation.compare("a", "A", casing: :sensitive) == :lt
  end

  test "Enum.sort" do
    assert Enum.sort(["AAAA", "AAAa"], Cldr.Collation.Insensitive) == ["AAAA", "AAAa"]
    assert Enum.sort(["AAAA", "AAAa"], Cldr.Collation.Sensitive) == ["AAAa", "AAAA"]
  end
end
