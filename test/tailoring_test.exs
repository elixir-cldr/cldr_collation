defmodule Collation.TailoringTest do
  use ExUnit.Case, async: true

  describe "parse_rules/1" do
    test "parses simple primary tailoring" do
      ops = Collation.Tailoring.parse_rules("&N<ñ<<<Ñ")

      assert [{:reset, [?N]}, {:primary, [?ñ]}, {:tertiary, [?Ñ]}] = ops
    end

    test "parses secondary tailoring" do
      ops = Collation.Tailoring.parse_rules("&AE<<ä<<<Ä")

      assert [{:reset, [?A, ?E]}, {:secondary, [?ä]}, {:tertiary, [?Ä]}] = ops
    end

    test "parses multi-character contraction" do
      ops = Collation.Tailoring.parse_rules("&C<ch<<<Ch<<<CH")

      assert [
               {:reset, [?C]},
               {:primary, [?c, ?h]},
               {:tertiary, [?C, ?h]},
               {:tertiary, [?C, ?H]}
             ] = ops
    end

    test "parses option override" do
      ops = Collation.Tailoring.parse_rules("[caseFirst upper]")
      assert [{:option, :case_first, :upper}] = ops
    end

    test "parses before reset" do
      ops = Collation.Tailoring.parse_rules("&[before 1]ǀ<æ<<<Æ")

      assert [
               {:reset_before, 1, [?ǀ]},
               {:primary, [?æ]},
               {:tertiary, [?Æ]}
             ] = ops
    end

    test "parses multiple lines" do
      rules = "&N<ñ<<<Ñ\n&C<ch<<<Ch<<<CH"
      ops = Collation.Tailoring.parse_rules(rules)
      assert length(ops) == 7
    end
  end

  describe "get_tailoring/2" do
    setup do
      Collation.ensure_loaded()
      :ok
    end

    test "returns overlay for Spanish standard" do
      {overlay, opts} = Collation.Tailoring.get_tailoring("es", :standard)
      assert is_map(overlay)
      assert map_size(overlay) > 0
      assert opts == []
    end

    test "returns overlay with option overrides for Danish" do
      {overlay, opts} = Collation.Tailoring.get_tailoring("da", :standard)
      assert is_map(overlay)
      assert opts == [case_first: :upper]
    end

    test "returns overlay for German phonebook" do
      {overlay, opts} = Collation.Tailoring.get_tailoring("de", :phonebook)
      assert is_map(overlay)
      assert opts == []
      # Should have entries for ä, ö, ü, Ä, Ö, Ü
      assert Map.has_key?(overlay, [?ä])
      assert Map.has_key?(overlay, [?ö])
      assert Map.has_key?(overlay, [?ü])
    end

    test "returns nil for unsupported locale" do
      assert nil == Collation.Tailoring.get_tailoring("en", :standard)
    end
  end

  describe "supported_locales/0" do
    test "lists available tailorings" do
      locales = Collation.Tailoring.supported_locales()
      assert {"es", :standard} in locales
      assert {"de", :phonebook} in locales
      assert {"sv", :standard} in locales
    end
  end

  describe "Spanish locale integration" do
    test "ñ sorts after n" do
      assert Collation.compare("ñ", "n", locale: "es") == :gt
      assert Collation.compare("ñ", "o", locale: "es") == :lt
    end

    test "sort with ñ" do
      result = Collation.sort(["obra", "ñoño", "nube"], locale: "es")
      assert result == ["nube", "ñoño", "obra"]
    end
  end

  describe "Spanish traditional locale integration" do
    test "ch sorts after c" do
      assert Collation.compare("ch", "c", locale: "es-u-co-trad") == :gt
      assert Collation.compare("ch", "d", locale: "es-u-co-trad") == :lt
    end

    test "ll sorts after l" do
      assert Collation.compare("ll", "l", locale: "es-u-co-trad") == :gt
      assert Collation.compare("ll", "m", locale: "es-u-co-trad") == :lt
    end
  end

  describe "Swedish locale integration" do
    test "å ä ö sort after z" do
      assert Collation.compare("å", "z", locale: "sv") == :gt
      assert Collation.compare("ä", "z", locale: "sv") == :gt
      assert Collation.compare("ö", "z", locale: "sv") == :gt
    end

    test "å sorts before ä which sorts before ö" do
      assert Collation.compare("å", "ä", locale: "sv") == :lt
      assert Collation.compare("ä", "ö", locale: "sv") == :lt
    end

    test "sort Swedish letters" do
      result = Collation.sort(["öl", "ål", "äl", "zl"], locale: "sv")
      assert result == ["zl", "ål", "äl", "öl"]
    end
  end

  describe "German phonebook locale integration" do
    test "ä sorts near ae, before af" do
      # In phonebook order, ä is a secondary variant of AE
      # ä should sort after "ae" (secondary difference) but before "af" (primary)
      assert Collation.compare("ä", "af", locale: "de-u-co-phonebk") == :lt
    end

    test "ö sorts before of" do
      assert Collation.compare("ö", "of", locale: "de-u-co-phonebk") == :lt
    end

    test "ü sorts before uf" do
      assert Collation.compare("ü", "uf", locale: "de-u-co-phonebk") == :lt
    end
  end

  describe "Polish locale integration" do
    test "ą sorts after a" do
      assert Collation.compare("ą", "a", locale: "pl") == :gt
      assert Collation.compare("ą", "b", locale: "pl") == :lt
    end

    test "ć sorts after c" do
      assert Collation.compare("ć", "c", locale: "pl") == :gt
      assert Collation.compare("ć", "d", locale: "pl") == :lt
    end

    test "ź and ż sort after z" do
      assert Collation.compare("ź", "z", locale: "pl") == :gt
      assert Collation.compare("ż", "z", locale: "pl") == :gt
      assert Collation.compare("ź", "ż", locale: "pl") == :lt
    end
  end

  describe "Danish locale integration" do
    test "æ ø å sort after z" do
      assert Collation.compare("æ", "z", locale: "da") == :gt
      assert Collation.compare("ø", "z", locale: "da") == :gt
      assert Collation.compare("å", "z", locale: "da") == :gt
    end

    test "sort order: æ before ø before å" do
      assert Collation.compare("æ", "ø", locale: "da") == :lt
      assert Collation.compare("ø", "å", locale: "da") == :lt
    end
  end

  describe "locale defaults" do
    test "Danish sets case_first to upper" do
      opts = Collation.Options.from_locale("da")
      assert opts.case_first == :upper
    end

    test "BCP47 keys override locale defaults" do
      opts = Collation.Options.from_locale("da-u-kf-lower")
      assert opts.case_first == :lower
    end

    test "unknown locale returns default options with no tailoring" do
      opts = Collation.Options.from_locale("en")
      assert opts.tailoring == nil
    end
  end
end
