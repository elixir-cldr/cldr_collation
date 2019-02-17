defmodule CldrCollationTest do
  use ExUnit.Case
  doctest Cldr.Collation

  test "collation" do
    assert Cldr.Collation.compare("a", "A", casing: :insensitive) == :eq
    assert Cldr.Collation.compare("a", "A", casing: :sensitive) == :lt
  end
end
