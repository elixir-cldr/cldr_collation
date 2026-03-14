defmodule Collation.TailoringTest do
  use ExUnit.Case, async: true

  # ===================================================================
  # Rule Parser Unit Tests
  # ===================================================================

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

  # ===================================================================
  # Tailoring overlay unit tests
  # ===================================================================

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

  # ===================================================================
  # Locale defaults tests
  # ===================================================================

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

  # ===================================================================
  # ICU4C decoll.cpp / ICU4J CollationGermanTest — Standard German
  # All 12 pairs use standard de_DE collation (NOT phonebook).
  # Source: unicode-org/icu CollationGermanTest.java
  # ===================================================================

  describe "ICU German standard (de) — from CollationGermanTest.java" do
    # results[i] = {primary_result, tertiary_result}
    # Pair 0: "Größe" vs "Grossist"  => {LESS, LESS}
    test "Größe < Grossist at primary" do
      assert Collation.compare("Größe", "Grossist", strength: :primary) == :lt
    end

    test "Größe < Grossist at tertiary" do
      assert Collation.compare("Größe", "Grossist", strength: :tertiary) == :lt
    end

    # Pair 1: "abc" vs "a\u0308bc"  => {EQUAL, LESS}
    test "abc = a\u0308bc at primary" do
      assert Collation.compare("abc", "a\u0308bc", strength: :primary) == :eq
    end

    test "abc < a\u0308bc at tertiary" do
      assert Collation.compare("abc", "a\u0308bc", strength: :tertiary) == :lt
    end

    # Pair 2: "Töne" vs "Ton"  => {GREATER, GREATER}
    test "Töne > Ton at primary" do
      assert Collation.compare("Töne", "Ton", strength: :primary) == :gt
    end

    test "Töne > Ton at tertiary" do
      assert Collation.compare("Töne", "Ton", strength: :tertiary) == :gt
    end

    # Pair 3: "Töne" vs "Tod"  => {GREATER, GREATER}
    test "Töne > Tod at primary" do
      assert Collation.compare("Töne", "Tod", strength: :primary) == :gt
    end

    # Pair 4: "Töne" vs "Tofu"  => {GREATER, GREATER}
    test "Töne > Tofu at primary" do
      assert Collation.compare("Töne", "Tofu", strength: :primary) == :gt
    end

    # Pair 5: "a\u0308bc" vs "A\u0308bc"  => {EQUAL, LESS}
    test "a\u0308bc = A\u0308bc at primary" do
      assert Collation.compare("a\u0308bc", "A\u0308bc", strength: :primary) == :eq
    end

    test "a\u0308bc < A\u0308bc at tertiary" do
      assert Collation.compare("a\u0308bc", "A\u0308bc", strength: :tertiary) == :lt
    end

    # Pair 6: "äbc" vs "a\u0308bc"  => {EQUAL, EQUAL}
    test "äbc = a\u0308bc at primary" do
      assert Collation.compare("äbc", "a\u0308bc", strength: :primary) == :eq
    end

    test "äbc = a\u0308bc at tertiary" do
      assert Collation.compare("äbc", "a\u0308bc", strength: :tertiary) == :eq
    end

    # Pair 7: "äbc" vs "aebc"  => {LESS, LESS}
    test "äbc < aebc at primary (standard — ä is NOT ae)" do
      assert Collation.compare("äbc", "aebc", strength: :primary) == :lt
    end

    test "äbc < aebc at tertiary" do
      assert Collation.compare("äbc", "aebc", strength: :tertiary) == :lt
    end

    # Pair 8: "Straße" vs "Strasse"  => {EQUAL, GREATER}
    test "Straße = Strasse at primary" do
      assert Collation.compare("Straße", "Strasse", strength: :primary) == :eq
    end

    test "Straße > Strasse at tertiary" do
      assert Collation.compare("Straße", "Strasse", strength: :tertiary) == :gt
    end

    # Pair 9: "efg" vs "efg"  => {EQUAL, EQUAL}
    test "efg = efg at primary" do
      assert Collation.compare("efg", "efg", strength: :primary) == :eq
    end

    test "efg = efg at tertiary" do
      assert Collation.compare("efg", "efg", strength: :tertiary) == :eq
    end

    # Pairs 10-11 repeat pairs 7-8 (same results in standard German)
    test "äbc < aebc at primary (standard, pair 10)" do
      assert Collation.compare("äbc", "aebc", strength: :primary) == :lt
    end

    test "Straße > Strasse at tertiary (pair 11)" do
      assert Collation.compare("Straße", "Strasse", strength: :tertiary) == :gt
    end
  end

  # ===================================================================
  # ICU4C escoll.cpp / ICU4J CollationSpanishTest — Spanish traditional
  # ===================================================================

  describe "ICU Spanish traditional (es-u-co-trad) — from escoll.cpp" do
    # Source: unicode-org/icu icu4c/source/test/intltest/escoll.cpp
    # Tests 0-4 use traditional Spanish (ch, ll as separate letters)

    @trad_locale "es-u-co-trad"

    test "alias < allias at tertiary (traditional ch/ll)" do
      assert Collation.compare("alias", "allias", locale: @trad_locale) == :lt
    end

    test "Elliot < Emiot at tertiary (traditional)" do
      assert Collation.compare("Elliot", "Emiot", locale: @trad_locale) == :lt
    end

    test "Hello > hellO at tertiary (traditional)" do
      assert Collation.compare("Hello", "hellO", locale: @trad_locale) == :gt
    end

    test "acHc < aCHc at tertiary (traditional, CH is a letter)" do
      assert Collation.compare("acHc", "aCHc", locale: @trad_locale) == :lt
    end

    test "acc < aCHc at tertiary (traditional, CH after C)" do
      assert Collation.compare("acc", "aCHc", locale: @trad_locale) == :lt
    end

    # Tests 5-8 use primary strength (standard Spanish behavior)
    test "alias < allias at primary (standard es)" do
      assert Collation.compare("alias", "allias", locale: "es", strength: :primary) == :lt
    end

    test "Hello = hellO at primary (standard es)" do
      assert Collation.compare("Hello", "hellO", locale: "es", strength: :primary) == :eq
    end
  end

  # ===================================================================
  # ICU4C ficoll.cpp / ICU4J CollationFinnishTest — Finnish
  # ===================================================================

  describe "ICU Finnish (fi) — from ficoll.cpp" do
    # Source: unicode-org/icu icu4c/source/test/intltest/ficoll.cpp

    @fi_locale "fi"

    test "wat > vat at tertiary (w after v)" do
      assert Collation.compare("wat", "vat", locale: @fi_locale) == :gt
    end

    test "vat < way at tertiary" do
      assert Collation.compare("vat", "way", locale: @fi_locale) == :lt
    end

    test "aübeck > axbeck at tertiary (ü after x)" do
      assert Collation.compare("aübeck", "axbeck", locale: @fi_locale) == :gt
    end

    test "Låvi < Läwe at tertiary (å before ä)" do
      assert Collation.compare("Låvi", "Läwe", locale: @fi_locale) == :lt
    end

    test "wat > vat at primary (v < w per cldrbug 6615)" do
      assert Collation.compare("wat", "vat", locale: @fi_locale, strength: :primary) == :gt
    end
  end

  # ===================================================================
  # ICU4C trcoll.cpp / ICU4J CollationTurkishTest — Turkish
  # ===================================================================

  describe "ICU Turkish (tr) — from trcoll.cpp" do
    # Source: unicode-org/icu icu4c/source/test/intltest/trcoll.cpp

    @tr_locale "tr"

    test "old < Öay at tertiary (ö after o)" do
      assert Collation.compare("old", "Öay", locale: @tr_locale) == :lt
    end

    test "üoid < void at tertiary (ü after u, before v)" do
      assert Collation.compare("üoid", "void", locale: @tr_locale) == :lt
    end

    test "üoid < void at primary" do
      assert Collation.compare("üoid", "void", locale: @tr_locale, strength: :primary) == :lt
    end
  end

  # ===================================================================
  # Danish sort order — adapted from ICU4C decoll.cpp / collationtest.txt
  # ===================================================================

  describe "ICU Danish (da) sort order — from collationtest.txt" do
    # Danish: Æ/Ä sort after Z, then Ø/Ö, then Å
    # Source: unicode-org/icu testdata/collationtest.txt

    @da_locale "da"

    test "æ ø å sort after z" do
      assert Collation.compare("æ", "z", locale: @da_locale) == :gt
      assert Collation.compare("ø", "z", locale: @da_locale) == :gt
      assert Collation.compare("å", "z", locale: @da_locale) == :gt
    end

    test "sort order: æ before ø before å" do
      assert Collation.compare("æ", "ø", locale: @da_locale) == :lt
      assert Collation.compare("ø", "å", locale: @da_locale) == :lt
    end

    test "ä is secondary variant of æ" do
      # In Danish, ä sorts as a secondary variant of æ
      assert Collation.compare("ä", "æ", locale: @da_locale) == :gt
    end

    test "ö is secondary variant of ø" do
      # In Danish, ö sorts as a secondary variant of ø
      assert Collation.compare("ö", "ø", locale: @da_locale) == :gt
    end

    test "ÆBLE < ÄBLE (æ before ä in Danish)" do
      assert Collation.compare("ÆBLE", "ÄBLE", locale: @da_locale) == :lt
    end

    test "ØBERG < ÖBERG (ø before ö in Danish)" do
      assert Collation.compare("ØBERG", "ÖBERG", locale: @da_locale) == :lt
    end

    test "large Danish sort order from ICU test data" do
      # Adapted from the Danish tertiary sort order in ICU collationtest.txt
      # Each pair should sort in the given order
      sorted_pairs = [
        {"CA", "ÇA"},
        {"DA", "ÐA"},
        {"HAAG", "HÅNDBOG"},
        {"STORM PETERSEN", "STORMLY"},
        {"VESTERGÅRD, A", "VESTERGAARD, A"},
        {"ÆBLE", "ÄBLE"},
        {"ØBERG", "ÖBERG"}
      ]

      for {a, b} <- sorted_pairs do
        result = Collation.compare(a, b, locale: @da_locale)

        assert result == :lt,
               "Expected #{inspect(a)} < #{inspect(b)} in Danish, got #{inspect(result)}"
      end
    end
  end

  # ===================================================================
  # Swedish — additional tests from Finnish shared rules
  # ===================================================================

  describe "Swedish (sv) locale integration" do
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

    test "æ is secondary variant of ä in Swedish" do
      # In Swedish, ä is the primary letter and æ is secondary variant
      assert Collation.compare("ä", "æ", locale: "sv") == :lt
    end

    test "ø is secondary variant of ö in Swedish" do
      assert Collation.compare("ö", "ø", locale: "sv") == :lt
    end

    test "đ sorts as secondary variant of d" do
      assert Collation.compare("đ", "d", locale: "sv") == :gt
      assert Collation.compare("đ", "e", locale: "sv") == :lt
    end

    test "ü sorts as secondary variant of y" do
      assert Collation.compare("ü", "y", locale: "sv") == :gt
      assert Collation.compare("ü", "z", locale: "sv") == :lt
    end
  end

  # ===================================================================
  # Polish — full alphabet tests
  # ===================================================================

  describe "Polish (pl) locale integration" do
    test "ą sorts after a, before b" do
      assert Collation.compare("ą", "a", locale: "pl") == :gt
      assert Collation.compare("ą", "b", locale: "pl") == :lt
    end

    test "ć sorts after c, before d" do
      assert Collation.compare("ć", "c", locale: "pl") == :gt
      assert Collation.compare("ć", "d", locale: "pl") == :lt
    end

    test "ę sorts after e, before f" do
      assert Collation.compare("ę", "e", locale: "pl") == :gt
      assert Collation.compare("ę", "f", locale: "pl") == :lt
    end

    test "ł sorts after l, before m" do
      assert Collation.compare("ł", "l", locale: "pl") == :gt
      assert Collation.compare("ł", "m", locale: "pl") == :lt
    end

    test "ń sorts after n, before o" do
      assert Collation.compare("ń", "n", locale: "pl") == :gt
      assert Collation.compare("ń", "o", locale: "pl") == :lt
    end

    test "ó sorts after o, before p" do
      assert Collation.compare("ó", "o", locale: "pl") == :gt
      assert Collation.compare("ó", "p", locale: "pl") == :lt
    end

    test "ś sorts after s, before t" do
      assert Collation.compare("ś", "s", locale: "pl") == :gt
      assert Collation.compare("ś", "t", locale: "pl") == :lt
    end

    test "ź and ż sort after z" do
      assert Collation.compare("ź", "z", locale: "pl") == :gt
      assert Collation.compare("ż", "z", locale: "pl") == :gt
      assert Collation.compare("ź", "ż", locale: "pl") == :lt
    end

    test "full Polish sort order" do
      input = ["żar", "źle", "zupa", "świt", "sam", "tata", "łódź", "las", "mama"]
      result = Collation.sort(input, locale: "pl")
      assert result == ["las", "łódź", "mama", "sam", "świt", "tata", "zupa", "źle", "żar"]
    end
  end

  # ===================================================================
  # Croatian — digraph contractions from ICU capitst.c
  # ===================================================================

  describe "Croatian (hr) locale integration" do
    test "č sorts after c, before ć" do
      assert Collation.compare("č", "c", locale: "hr") == :gt
      assert Collation.compare("č", "ć", locale: "hr") == :lt
    end

    test "ć sorts after č, before d" do
      assert Collation.compare("ć", "č", locale: "hr") == :gt
      assert Collation.compare("ć", "d", locale: "hr") == :lt
    end

    test "dž digraph sorts after d, before đ" do
      assert Collation.compare("dž", "d", locale: "hr") == :gt
      assert Collation.compare("dž", "đ", locale: "hr") == :lt
    end

    test "đ sorts after dž, before e" do
      assert Collation.compare("đ", "dž", locale: "hr") == :gt
      assert Collation.compare("đ", "e", locale: "hr") == :lt
    end

    test "lj digraph sorts after l, before m" do
      assert Collation.compare("lj", "l", locale: "hr") == :gt
      assert Collation.compare("lj", "m", locale: "hr") == :lt
    end

    test "nj digraph sorts after n, before o" do
      assert Collation.compare("nj", "n", locale: "hr") == :gt
      assert Collation.compare("nj", "o", locale: "hr") == :lt
    end

    test "š sorts after s, before t" do
      assert Collation.compare("š", "s", locale: "hr") == :gt
      assert Collation.compare("š", "t", locale: "hr") == :lt
    end

    test "ž sorts after z" do
      assert Collation.compare("ž", "z", locale: "hr") == :gt
    end

    test "Croatian digraph case variants" do
      # dž <<< Dž <<< DŽ (tertiary variants)
      assert Collation.compare("dž", "Dž", locale: "hr") == :lt
      assert Collation.compare("Dž", "DŽ", locale: "hr") == :lt
    end
  end

  # ===================================================================
  # Spanish standard (es) — ñ only
  # ===================================================================

  describe "Spanish standard (es) locale integration" do
    test "ñ sorts after n, before o" do
      assert Collation.compare("ñ", "n", locale: "es") == :gt
      assert Collation.compare("ñ", "o", locale: "es") == :lt
    end

    test "sort with ñ" do
      result = Collation.sort(["obra", "ñoño", "nube"], locale: "es")
      assert result == ["nube", "ñoño", "obra"]
    end
  end

  # ===================================================================
  # Spanish traditional — ch and ll contractions
  # ===================================================================

  describe "Spanish traditional (es-u-co-trad) locale integration" do
    test "ch sorts after c, before d" do
      assert Collation.compare("ch", "c", locale: "es-u-co-trad") == :gt
      assert Collation.compare("ch", "d", locale: "es-u-co-trad") == :lt
    end

    test "ll sorts after l, before m" do
      assert Collation.compare("ll", "l", locale: "es-u-co-trad") == :gt
      assert Collation.compare("ll", "m", locale: "es-u-co-trad") == :lt
    end
  end

  # ===================================================================
  # Norwegian (nb/nn) — same rules as Danish
  # ===================================================================

  describe "Norwegian Bokmål (nb) locale" do
    test "æ ø å sort after z" do
      assert Collation.compare("æ", "z", locale: "nb") == :gt
      assert Collation.compare("ø", "z", locale: "nb") == :gt
      assert Collation.compare("å", "z", locale: "nb") == :gt
    end

    test "sort order matches Danish: æ < ø < å" do
      assert Collation.compare("æ", "ø", locale: "nb") == :lt
      assert Collation.compare("ø", "å", locale: "nb") == :lt
    end

    test "Norwegian Bokmål sets case_first to upper" do
      opts = Collation.Options.from_locale("nb")
      assert opts.case_first == :upper
    end
  end

  describe "Norwegian Nynorsk (nn) locale" do
    test "æ ø å sort after z (same as Bokmål)" do
      assert Collation.compare("æ", "z", locale: "nn") == :gt
      assert Collation.compare("ø", "z", locale: "nn") == :gt
      assert Collation.compare("å", "z", locale: "nn") == :gt
    end

    test "Norwegian Nynorsk sets case_first to upper" do
      opts = Collation.Options.from_locale("nn")
      assert opts.case_first == :upper
    end
  end

  # ===================================================================
  # German phonebook — expansion behavior tests
  # ===================================================================

  describe "German phonebook expansion behavior" do
    @phonebk_locale "de-u-co-phonebk"

    test "ä sorts near ae, before af" do
      # ä is a secondary variant of AE so it sorts before "af" at primary level
      assert Collation.compare("ä", "af", locale: @phonebk_locale) == :lt
    end

    test "ö sorts before of" do
      assert Collation.compare("ö", "of", locale: @phonebk_locale) == :lt
    end

    test "ü sorts before uf" do
      assert Collation.compare("ü", "uf", locale: @phonebk_locale) == :lt
    end
  end
end
