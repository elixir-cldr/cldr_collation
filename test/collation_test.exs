defmodule CollationTest do
  use ExUnit.Case

  setup_all do
    Collation.ensure_loaded()
    :ok
  end

  describe "compare/3" do
    test "identical strings are equal" do
      assert Collation.compare("hello", "hello") == :eq
    end

    test "basic Latin ordering" do
      assert Collation.compare("a", "b") == :lt
      assert Collation.compare("b", "a") == :gt
      assert Collation.compare("abc", "abd") == :lt
    end

    test "case ordering at tertiary level" do
      # Lowercase sorts before uppercase at default (tertiary) strength
      assert Collation.compare("a", "A") == :lt
      assert Collation.compare("A", "a") == :gt
    end

    test "case ignored at secondary strength" do
      assert Collation.compare("a", "A", strength: :secondary) == :eq
      assert Collation.compare("abc", "ABC", strength: :secondary) == :eq
    end

    test "accent ordering" do
      # Accented characters sort after base at secondary level
      assert Collation.compare("e", "é") == :lt
      assert Collation.compare("é", "e") == :gt
    end

    test "accents ignored at primary strength" do
      assert Collation.compare("e", "é", strength: :primary) == :eq
      assert Collation.compare("cafe", "café", strength: :primary) == :eq
    end

    test "shorter string sorts before longer when prefix matches" do
      assert Collation.compare("abc", "abcd") == :lt
    end

    test "space sorts before letters" do
      assert Collation.compare(" ", "a") == :lt
    end

    test "digits sort before letters" do
      assert Collation.compare("1", "a") == :lt
    end
  end

  describe "sort/2" do
    test "sorts basic Latin strings" do
      assert Collation.sort(["c", "a", "b"]) == ["a", "b", "c"]
    end

    test "sorts with accents" do
      result = Collation.sort(["é", "e", "ê", "ë"])
      # All 'e' variants should sort together, with plain 'e' first
      assert hd(result) == "e"
    end

    test "sorts mixed case" do
      result = Collation.sort(["B", "a", "b", "A"])
      # At tertiary: a < A < b < B
      assert result == ["a", "A", "b", "B"]
    end

    test "sorts empty strings" do
      assert Collation.sort(["b", "", "a"]) == ["", "a", "b"]
    end
  end

  describe "sort_key/2" do
    test "returns binary" do
      assert is_binary(Collation.sort_key("hello"))
    end

    test "sort keys maintain ordering" do
      key_a = Collation.sort_key("a")
      key_b = Collation.sort_key("b")
      assert key_a < key_b
    end

    test "identical strings produce identical sort keys" do
      assert Collation.sort_key("hello") == Collation.sort_key("hello")
    end

    test "empty string produces a sort key" do
      key = Collation.sort_key("")
      assert is_binary(key)
    end
  end
end
