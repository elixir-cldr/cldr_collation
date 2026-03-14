defmodule Cldr.CollationTest do
  use ExUnit.Case

  setup_all do
    Cldr.Collation.ensure_loaded()
    :ok
  end

  describe "compare/3" do
    test "identical strings are equal" do
      assert Cldr.Collation.compare("hello", "hello") == :eq
    end

    test "basic Latin ordering" do
      assert Cldr.Collation.compare("a", "b") == :lt
      assert Cldr.Collation.compare("b", "a") == :gt
      assert Cldr.Collation.compare("abc", "abd") == :lt
    end

    test "case ordering at tertiary level" do
      # Lowercase sorts before uppercase at default (tertiary) strength
      assert Cldr.Collation.compare("a", "A") == :lt
      assert Cldr.Collation.compare("A", "a") == :gt
    end

    test "case ignored at secondary strength" do
      assert Cldr.Collation.compare("a", "A", strength: :secondary) == :eq
      assert Cldr.Collation.compare("abc", "ABC", strength: :secondary) == :eq
    end

    test "accent ordering" do
      # Accented characters sort after base at secondary level
      assert Cldr.Collation.compare("e", "é") == :lt
      assert Cldr.Collation.compare("é", "e") == :gt
    end

    test "accents ignored at primary strength" do
      assert Cldr.Collation.compare("e", "é", strength: :primary) == :eq
      assert Cldr.Collation.compare("cafe", "café", strength: :primary) == :eq
    end

    test "shorter string sorts before longer when prefix matches" do
      assert Cldr.Collation.compare("abc", "abcd") == :lt
    end

    test "space sorts before letters" do
      assert Cldr.Collation.compare(" ", "a") == :lt
    end

    test "digits sort before letters" do
      assert Cldr.Collation.compare("1", "a") == :lt
    end
  end

  describe "sort/2" do
    test "sorts basic Latin strings" do
      assert Cldr.Collation.sort(["c", "a", "b"]) == ["a", "b", "c"]
    end

    test "sorts with accents" do
      result = Cldr.Collation.sort(["é", "e", "ê", "ë"])
      # All 'e' variants should sort together, with plain 'e' first
      assert hd(result) == "e"
    end

    test "sorts mixed case" do
      result = Cldr.Collation.sort(["B", "a", "b", "A"])
      # At tertiary: a < A < b < B
      assert result == ["a", "A", "b", "B"]
    end

    test "sorts empty strings" do
      assert Cldr.Collation.sort(["b", "", "a"]) == ["", "a", "b"]
    end
  end

  describe "sort_key/2" do
    test "returns binary" do
      assert is_binary(Cldr.Collation.sort_key("hello"))
    end

    test "sort keys maintain ordering" do
      key_a = Cldr.Collation.sort_key("a")
      key_b = Cldr.Collation.sort_key("b")
      assert key_a < key_b
    end

    test "identical strings produce identical sort keys" do
      assert Cldr.Collation.sort_key("hello") == Cldr.Collation.sort_key("hello")
    end

    test "empty string produces a sort key" do
      key = Cldr.Collation.sort_key("")
      assert is_binary(key)
    end
  end
end
