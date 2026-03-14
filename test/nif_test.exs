defmodule Cldr.Collation.NifTest do
  use ExUnit.Case, async: true

  describe "Cldr.Collation.Nif.available?/0" do
    test "returns a boolean" do
      assert is_boolean(Cldr.Collation.Nif.available?())
    end
  end

  describe "casing option compatibility" do
    test "casing: :insensitive treats a and A as equal" do
      assert Cldr.Collation.compare("a", "A", casing: :insensitive) == :eq
    end

    test "casing: :sensitive distinguishes a and A" do
      assert Cldr.Collation.compare("a", "A", casing: :sensitive) == :lt
    end

    test "casing: :insensitive is equivalent to strength: :secondary" do
      result_casing = Cldr.Collation.sort(["café", "Cafe", "cafe"], casing: :insensitive)
      result_strength = Cldr.Collation.sort(["café", "Cafe", "cafe"], strength: :secondary)
      assert result_casing == result_strength
    end

    test "invalid casing option raises" do
      assert_raise ArgumentError, ~r/invalid casing option/, fn ->
        Cldr.Collation.compare("a", "b", casing: :invalid)
      end
    end
  end

  describe "backend option" do
    test "backend: :elixir always uses pure Elixir" do
      assert Cldr.Collation.compare("a", "b", backend: :elixir) == :lt
    end

    test "backend: :elixir sort produces correct results" do
      assert Cldr.Collation.sort(["b", "a", "c"], backend: :elixir) == ["a", "b", "c"]
    end

    test "backend: :default falls back to elixir when NIF unavailable or options incompatible" do
      # With advanced options, NIF cannot be used even if available
      result = Cldr.Collation.sort(["b", "a"], backend: :default, numeric: true)
      assert result == ["a", "b"]
    end

    test "backend: :nif raises when NIF is unavailable" do
      unless Cldr.Collation.Nif.available?() do
        assert_raise RuntimeError, ~r/NIF collation backend requested but not available/, fn ->
          Cldr.Collation.compare("a", "b", backend: :nif)
        end
      end
    end

    test "backend: :nif with incompatible options raises" do
      if Cldr.Collation.Nif.available?() do
        assert_raise ArgumentError, ~r/NIF collation backend does not support/, fn ->
          Cldr.Collation.compare("a", "b", backend: :nif, numeric: true)
        end
      end
    end
  end

  describe "Cldr.Collation.Sensitive companion module" do
    test "compare/2 returns correct results" do
      assert Cldr.Collation.Sensitive.compare("a", "b") == :lt
      assert Cldr.Collation.Sensitive.compare("b", "a") == :gt
      assert Cldr.Collation.Sensitive.compare("a", "a") == :eq
    end

    test "works with Enum.sort/2" do
      sorted = Enum.sort(["c", "a", "b"], Cldr.Collation.Sensitive)
      assert sorted == ["a", "b", "c"]
    end

    test "case-sensitive ordering distinguishes case" do
      assert Cldr.Collation.Sensitive.compare("a", "A") == :lt
    end
  end

  describe "Cldr.Collation.Insensitive companion module" do
    test "compare/2 returns correct results" do
      assert Cldr.Collation.Insensitive.compare("a", "b") == :lt
      assert Cldr.Collation.Insensitive.compare("b", "a") == :gt
    end

    test "works with Enum.sort/2" do
      sorted = Enum.sort(["c", "a", "b"], Cldr.Collation.Insensitive)
      assert sorted == ["a", "b", "c"]
    end

    test "case-insensitive ordering treats a and A as equal" do
      assert Cldr.Collation.Insensitive.compare("a", "A") == :eq
    end
  end

  describe "Options.nif_compatible?/1" do
    test "default options are NIF-compatible" do
      assert Cldr.Collation.Options.nif_compatible?(%Cldr.Collation.Options{})
    end

    test "secondary strength is NIF-compatible" do
      assert Cldr.Collation.Options.nif_compatible?(%Cldr.Collation.Options{strength: :secondary})
    end

    test "primary strength is not NIF-compatible" do
      refute Cldr.Collation.Options.nif_compatible?(%Cldr.Collation.Options{strength: :primary})
    end

    test "numeric option is not NIF-compatible" do
      refute Cldr.Collation.Options.nif_compatible?(%Cldr.Collation.Options{numeric: true})
    end

    test "locale tailoring is not NIF-compatible" do
      refute Cldr.Collation.Options.nif_compatible?(%Cldr.Collation.Options{tailoring: %{}})
    end

    test "reorder is not NIF-compatible" do
      refute Cldr.Collation.Options.nif_compatible?(%Cldr.Collation.Options{reorder: ["Grek"]})
    end
  end
end
