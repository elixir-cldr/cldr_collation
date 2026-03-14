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
      # With tailoring options, NIF cannot be used even if available
      result = Cldr.Collation.sort(["b", "a"], backend: :default, tailoring: %{})
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
          Cldr.Collation.compare("a", "b", backend: :nif, tailoring: %{})
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

    test "all strength levels are NIF-compatible" do
      for strength <- [:primary, :secondary, :tertiary, :quaternary, :identical] do
        assert Cldr.Collation.Options.nif_compatible?(%Cldr.Collation.Options{strength: strength})
      end
    end

    test "numeric option is NIF-compatible" do
      assert Cldr.Collation.Options.nif_compatible?(%Cldr.Collation.Options{numeric: true})
    end

    test "backwards option is NIF-compatible" do
      assert Cldr.Collation.Options.nif_compatible?(%Cldr.Collation.Options{backwards: true})
    end

    test "alternate: :shifted is NIF-compatible" do
      assert Cldr.Collation.Options.nif_compatible?(%Cldr.Collation.Options{alternate: :shifted})
    end

    test "case_first is NIF-compatible" do
      assert Cldr.Collation.Options.nif_compatible?(%Cldr.Collation.Options{case_first: :upper})
      assert Cldr.Collation.Options.nif_compatible?(%Cldr.Collation.Options{case_first: :lower})
    end

    test "case_level is NIF-compatible" do
      assert Cldr.Collation.Options.nif_compatible?(%Cldr.Collation.Options{case_level: true})
    end

    test "normalization is NIF-compatible" do
      assert Cldr.Collation.Options.nif_compatible?(%Cldr.Collation.Options{normalization: true})
    end

    test "locale tailoring is not NIF-compatible" do
      refute Cldr.Collation.Options.nif_compatible?(%Cldr.Collation.Options{tailoring: %{}})
    end

    test "recognized reorder codes are NIF-compatible" do
      assert Cldr.Collation.Options.nif_compatible?(%Cldr.Collation.Options{reorder: ["Grek"]})
      assert Cldr.Collation.Options.nif_compatible?(%Cldr.Collation.Options{reorder: ["Grek", "Latn"]})
    end

    test "unrecognized reorder codes are not NIF-compatible" do
      refute Cldr.Collation.Options.nif_compatible?(%Cldr.Collation.Options{reorder: ["Unknown"]})
    end

    test "non-default max_variable is not NIF-compatible" do
      refute Cldr.Collation.Options.nif_compatible?(%Cldr.Collation.Options{max_variable: :space})
    end
  end

  # Tests that verify NIF and Elixir backends produce identical results.
  # These tests run with both backends explicitly and compare outputs.
  describe "NIF/Elixir parity" do
    # Helper to compare NIF and Elixir results
    defp assert_parity(a, b, opts) do
      nif_result = Cldr.Collation.compare(a, b, [{:backend, :nif} | opts])
      elixir_result = Cldr.Collation.compare(a, b, [{:backend, :elixir} | opts])

      assert nif_result == elixir_result,
             "NIF (#{inspect(nif_result)}) != Elixir (#{inspect(elixir_result)}) " <>
               "for compare(#{inspect(a)}, #{inspect(b)}, #{inspect(opts)})"
    end

    defp assert_sort_parity(strings, opts) do
      nif_result = Cldr.Collation.sort(strings, [{:backend, :nif} | opts])
      elixir_result = Cldr.Collation.sort(strings, [{:backend, :elixir} | opts])

      assert nif_result == elixir_result,
             "NIF sort != Elixir sort for #{inspect(opts)}"
    end

    @tag :nif
    test "strength: :primary" do
      if Cldr.Collation.Nif.available?() do
        assert_parity("a", "A", strength: :primary)
        assert_parity("café", "cafe", strength: :primary)
      end
    end

    @tag :nif
    test "strength: :secondary" do
      if Cldr.Collation.Nif.available?() do
        assert_parity("a", "A", strength: :secondary)
        assert_parity("café", "cafe", strength: :secondary)
      end
    end

    @tag :nif
    test "strength: :tertiary" do
      if Cldr.Collation.Nif.available?() do
        assert_parity("a", "A", strength: :tertiary)
        assert_parity("café", "cafe", strength: :tertiary)
      end
    end

    @tag :nif
    test "strength: :quaternary" do
      if Cldr.Collation.Nif.available?() do
        assert_parity("a", "A", strength: :quaternary)
        assert_parity("café", "cafe", strength: :quaternary)
      end
    end

    @tag :nif
    test "strength: :identical" do
      if Cldr.Collation.Nif.available?() do
        assert_parity("a", "A", strength: :identical)
      end
    end

    @tag :nif
    test "backwards: true (French collation)" do
      if Cldr.Collation.Nif.available?() do
        # French collation reverses secondary weights, affecting accent ordering
        assert_parity("côte", "coté", backwards: true)
        assert_parity("côte", "coté", backwards: false)
      end
    end

    @tag :nif
    test "alternate: :shifted" do
      if Cldr.Collation.Nif.available?() do
        # With shifted, punctuation/spaces are variable and may be ignored
        assert_parity("black-bird", "blackbird", alternate: :shifted)
        assert_parity("black bird", "blackbird", alternate: :shifted)
      end
    end

    @tag :nif
    test "case_first: :upper" do
      if Cldr.Collation.Nif.available?() do
        assert_parity("a", "A", case_first: :upper)
        assert_sort_parity(["a", "A", "b", "B"], case_first: :upper)
      end
    end

    @tag :nif
    test "case_first: :lower" do
      if Cldr.Collation.Nif.available?() do
        assert_parity("a", "A", case_first: :lower)
        assert_sort_parity(["a", "A", "b", "B"], case_first: :lower)
      end
    end

    @tag :nif
    test "case_level: true" do
      if Cldr.Collation.Nif.available?() do
        assert_parity("a", "A", case_level: true)
      end
    end

    @tag :nif
    test "normalization: true" do
      if Cldr.Collation.Nif.available?() do
        # é as single codepoint vs e + combining acute
        assert_parity("é", "e\u0301", normalization: true)
      end
    end

    @tag :nif
    test "numeric: true" do
      if Cldr.Collation.Nif.available?() do
        assert_parity("2", "10", numeric: true)
        assert_sort_parity(["file10", "file2", "file1"], numeric: true)
      end
    end

    @tag :nif
    test "combined options" do
      if Cldr.Collation.Nif.available?() do
        assert_parity("a", "A", strength: :secondary, numeric: true)
        assert_parity("2", "10", strength: :primary, numeric: true)
      end
    end

    @tag :nif
    test "NIF now handles numeric option directly" do
      if Cldr.Collation.Nif.available?() do
        # This previously would fall back to Elixir; now NIF handles it
        result = Cldr.Collation.compare("2", "10", backend: :nif, numeric: true)
        assert result == :lt
      end
    end

    @tag :nif
    test "reorder: Greek before Latin" do
      if Cldr.Collation.Nif.available?() do
        # Without reorder, Latin 'a' sorts before Greek 'α'
        assert Cldr.Collation.compare("a", "α", backend: :nif) == :lt

        # With reorder, Greek should come before Latin
        result = Cldr.Collation.compare("α", "a", backend: :nif, reorder: ["Grek"])
        assert result == :lt
      end
    end

    @tag :nif
    test "reorder: sort with script reordering" do
      if Cldr.Collation.Nif.available?() do
        strings = ["alpha", "α", "beta", "β"]

        nif_result = Cldr.Collation.sort(strings, backend: :nif, reorder: ["Grek"])

        # Greek strings should sort before Latin when Grek is first in reorder
        greek_positions = Enum.map(["α", "β"], &Enum.find_index(nif_result, fn s -> s == &1 end))
        latin_positions = Enum.map(["alpha", "beta"], &Enum.find_index(nif_result, fn s -> s == &1 end))

        assert Enum.max(greek_positions) < Enum.min(latin_positions),
               "Expected Greek strings before Latin, got: #{inspect(nif_result)}"
      end
    end

    @tag :nif
    test "reorder: empty list is no-op" do
      if Cldr.Collation.Nif.available?() do
        assert_parity("a", "α", reorder: [])
      end
    end

    @tag :nif
    test "reorder: with other options combined" do
      if Cldr.Collation.Nif.available?() do
        # Reorder + case insensitive
        nif_result =
          Cldr.Collation.sort(["A", "α", "a"], backend: :nif, reorder: ["Grek"], strength: :secondary)

        # Greek should still come first
        alpha_idx = Enum.find_index(nif_result, &(&1 == "α"))
        assert alpha_idx == 0, "Expected Greek α first, got: #{inspect(nif_result)}"
      end
    end

    @tag :nif
    test "unrecognized reorder codes fall back to Elixir with :default backend" do
      # Unrecognized codes should silently fall back to Elixir
      result = Cldr.Collation.sort(["b", "a"], backend: :default, reorder: ["Unknown"])
      assert result == ["a", "b"]
    end
  end

  describe "Nif.reorder_codes_supported?/1" do
    test "returns true for empty list" do
      assert Cldr.Collation.Nif.reorder_codes_supported?([])
    end

    test "returns true for recognized codes" do
      assert Cldr.Collation.Nif.reorder_codes_supported?(["Grek", "Latn", "Cyrl"])
      assert Cldr.Collation.Nif.reorder_codes_supported?(["space", "punct", "digit"])
    end

    test "returns false for unrecognized codes" do
      refute Cldr.Collation.Nif.reorder_codes_supported?(["Unknown"])
      refute Cldr.Collation.Nif.reorder_codes_supported?(["Grek", "BadCode"])
    end
  end
end
