defmodule Cldr.Collation.LanguageTagTest do
  use ExUnit.Case, async: true

  # These tests verify that a %Cldr.LanguageTag{} struct can be passed
  # as the :locale option to compare/3, sort/2 and sort_key/2, exercising
  # the options_from_language_tag/2 code path.

  defp language_tag(opts \\ []) do
    u_fields = Keyword.get(opts, :u, %{})
    language = Keyword.get(opts, :language, "en")
    backend = Keyword.get(opts, :backend, nil)
    cldr_locale_name = Keyword.get(opts, :cldr_locale_name, nil)

    %Cldr.LanguageTag{
      language: language,
      locale: struct(Cldr.LanguageTag.U, u_fields),
      backend: backend,
      cldr_locale_name: cldr_locale_name
    }
  end

  # ===================================================================
  # compare/3 with a LanguageTag :locale
  # ===================================================================

  describe "compare/3 with Cldr.LanguageTag locale" do
    test "default LanguageTag behaves like default options" do
      tag = language_tag()
      assert Cldr.Collation.compare("a", "b", locale: tag) == :lt
      assert Cldr.Collation.compare("b", "a", locale: tag) == :gt
      assert Cldr.Collation.compare("a", "a", locale: tag) == :eq
    end

    test "strength from LanguageTag (primary ignores case)" do
      tag = language_tag(u: %{col_strength: :primary})
      assert Cldr.Collation.compare("a", "A", locale: tag) == :eq
    end

    test "strength from LanguageTag (secondary)" do
      tag = language_tag(u: %{col_strength: :secondary})
      # Secondary ignores case but distinguishes accents
      assert Cldr.Collation.compare("a", "A", locale: tag) == :eq
      assert Cldr.Collation.compare("a", "\u00E4", locale: tag) == :lt
    end

    test "strength from LanguageTag (identical)" do
      tag = language_tag(u: %{col_strength: :identical})
      assert Cldr.Collation.compare("a", "A", locale: tag) == :lt
    end

    test "alternate shifted from LanguageTag" do
      tag = language_tag(u: %{col_alternate: :shifted})
      # With shifted, spaces/punctuation are ignorable at primary
      assert Cldr.Collation.compare("de luge", "de Luge",
               locale: tag, strength: :primary) == :eq
    end

    test "numeric sorting from LanguageTag" do
      tag = language_tag(u: %{col_numeric: :yes})
      assert Cldr.Collation.compare("file2", "file10", locale: tag) == :lt
    end

    test "backwards accent sorting from LanguageTag" do
      tag = language_tag(u: %{col_backwards: :yes})
      # French-style backwards accents: secondary weights compared right-to-left
      assert Cldr.Collation.compare("cot\u00E9", "c\u00F4te", locale: tag) == :gt
    end

    test "case_first upper from LanguageTag" do
      tag = language_tag(u: %{col_case_first: :upper})
      assert Cldr.Collation.compare("A", "a", locale: tag) == :lt
    end

    test "case_first lower from LanguageTag" do
      tag = language_tag(u: %{col_case_first: :lower})
      assert Cldr.Collation.compare("a", "A", locale: tag) == :lt
    end

    test "collation type from LanguageTag" do
      tag = language_tag(language: "de", u: %{collation: :phonebook})
      # In phonebook, umlauts expand: ä ≈ ae, so ä < af
      assert Cldr.Collation.compare("\u00E4", "af", locale: tag) == :lt
    end

    test "max_variable from LanguageTag" do
      tag = language_tag(u: %{kv: :space, col_alternate: :shifted})
      # With max_variable=space and alternate=shifted, spaces are ignorable
      assert Cldr.Collation.compare("de luge", "deluge",
               locale: tag, strength: :primary) == :eq
    end
  end

  # ===================================================================
  # sort/2 with a LanguageTag :locale
  # ===================================================================

  describe "sort/2 with Cldr.LanguageTag locale" do
    test "basic sort with default LanguageTag" do
      tag = language_tag()
      result = Cldr.Collation.sort(["cherry", "apple", "banana"], locale: tag)
      assert result == ["apple", "banana", "cherry"]
    end

    test "numeric sort with LanguageTag" do
      tag = language_tag(u: %{col_numeric: :yes})
      result = Cldr.Collation.sort(["file10", "file2", "file1"], locale: tag)
      assert result == ["file1", "file2", "file10"]
    end

    test "case_first upper sort with LanguageTag" do
      tag = language_tag(u: %{col_case_first: :upper})
      result = Cldr.Collation.sort(["a", "A", "b", "B"], locale: tag)
      assert result == ["A", "a", "B", "b"]
    end

    test "phonebook collation type sort with LanguageTag" do
      tag = language_tag(language: "de", u: %{collation: :phonebook})
      result = Cldr.Collation.sort(["\u00F6l", "of", "ob"], locale: tag)
      # In phonebook, ö expands to oe, so öl ≈ oel sorts after ob and before of
      assert result == ["ob", "\u00F6l", "of"]
    end
  end

  # ===================================================================
  # sort_key/2 with a LanguageTag :locale
  # ===================================================================

  describe "sort_key/2 with Cldr.LanguageTag locale" do
    test "sort keys reflect strength setting" do
      tag_primary = language_tag(u: %{col_strength: :primary})
      tag_tertiary = language_tag(u: %{col_strength: :tertiary})

      key_primary = Cldr.Collation.sort_key("abc", locale: tag_primary)
      key_tertiary = Cldr.Collation.sort_key("abc", locale: tag_tertiary)

      # Primary key should be shorter (fewer weight levels)
      assert byte_size(key_primary) < byte_size(key_tertiary)
    end

    test "sort key with numeric option produces correct ordering" do
      tag = language_tag(u: %{col_numeric: :yes})
      key2 = Cldr.Collation.sort_key("file2", locale: tag)
      key10 = Cldr.Collation.sort_key("file10", locale: tag)

      assert key2 < key10
    end
  end

  # ===================================================================
  # Extra keyword options override LanguageTag values
  # ===================================================================

  describe "extra keyword options override LanguageTag values" do
    test "explicit strength option overrides tag strength" do
      tag = language_tag(u: %{col_strength: :primary})
      # Tag says primary (would make a == A), but explicit option overrides to tertiary
      assert Cldr.Collation.compare("a", "A", locale: tag, strength: :tertiary) == :lt
    end

    test "explicit numeric option overrides tag numeric" do
      tag = language_tag(u: %{col_numeric: :yes})
      # Tag enables numeric, but explicit option disables it
      result = Cldr.Collation.sort(["file10", "file2", "file1"],
                 locale: tag, numeric: false)
      assert result == ["file1", "file10", "file2"]
    end
  end

  # ===================================================================
  # Multiple U extension fields combined
  # ===================================================================

  describe "LanguageTag with multiple U extension fields" do
    test "strength + numeric combined" do
      tag = language_tag(u: %{col_strength: :primary, col_numeric: :yes})
      assert Cldr.Collation.compare("File2", "file10", locale: tag) == :lt
    end

    test "backwards + case_first combined" do
      tag = language_tag(u: %{col_backwards: :yes, col_case_first: :upper})
      # Both backwards accents and upper-first should be applied
      assert Cldr.Collation.compare("A", "a", locale: tag) == :lt
    end
  end

  # ===================================================================
  # Locale resolution from LanguageTag
  # ===================================================================

  describe "locale defaults resolved from LanguageTag" do
    test "Danish locale defaults applied via cldr_locale_name" do
      tag = language_tag(language: "da", cldr_locale_name: :da)
      # Danish sets case_first: :upper by default
      assert Cldr.Collation.compare("A", "a", locale: tag) == :lt
    end

    test "Danish locale defaults applied via language fallback" do
      tag = language_tag(language: "da")
      # Without cldr_locale_name, language field is used
      assert Cldr.Collation.compare("A", "a", locale: tag) == :lt
    end

    test "cldr_locale_name takes precedence over language" do
      # cldr_locale_name says Danish (case_first: :upper)
      # but language says English (no locale defaults)
      tag = language_tag(language: "en", cldr_locale_name: :da)
      assert Cldr.Collation.compare("A", "a", locale: tag) == :lt
    end

    test "Norwegian Bokmal locale defaults via cldr_locale_name" do
      tag = language_tag(language: "nb", cldr_locale_name: :nb)
      # Norwegian Bokmal sets case_first: :upper
      assert Cldr.Collation.compare("A", "a", locale: tag) == :lt
    end

    test "U extension overrides locale defaults" do
      tag = language_tag(
        language: "da",
        cldr_locale_name: :da,
        u: %{col_case_first: :lower}
      )
      # U extension says lower, overriding Danish default of upper
      assert Cldr.Collation.compare("a", "A", locale: tag) == :lt
    end
  end

  describe "tailoring resolved from LanguageTag" do
    test "Spanish ñ tailoring via language" do
      tag = language_tag(language: "es")
      # Spanish tailoring: ñ sorts after n, before o
      assert Cldr.Collation.compare("\u00F1", "n", locale: tag) == :gt
      assert Cldr.Collation.compare("\u00F1", "o", locale: tag) == :lt
    end

    test "Spanish ñ tailoring via cldr_locale_name" do
      tag = language_tag(language: "es", cldr_locale_name: :es)
      assert Cldr.Collation.compare("\u00F1", "n", locale: tag) == :gt
      assert Cldr.Collation.compare("\u00F1", "o", locale: tag) == :lt
    end

    test "German phonebook tailoring via language" do
      tag = language_tag(language: "de", u: %{collation: :phonebook})
      # Phonebook: ä expands to ae, so ä sorts near ae and before af
      assert Cldr.Collation.compare("\u00E4", "af", locale: tag) == :lt
      assert Cldr.Collation.compare("\u00F6", "of", locale: tag) == :lt
    end

    test "Spanish traditional tailoring via U extension" do
      tag = language_tag(language: "es", u: %{collation: :traditional})
      # Traditional Spanish: ch sorts after c, before d
      assert Cldr.Collation.compare("ch", "c", locale: tag) == :gt
      assert Cldr.Collation.compare("ch", "d", locale: tag) == :lt
    end

    test "Danish tailoring sorts æ ø å after z" do
      tag = language_tag(language: "da", cldr_locale_name: :da)
      assert Cldr.Collation.compare("\u00E6", "z", locale: tag) == :gt
      assert Cldr.Collation.compare("\u00F8", "z", locale: tag) == :gt
      assert Cldr.Collation.compare("\u00E5", "z", locale: tag) == :gt
    end

    test "Swedish tailoring sorts å ä ö after z" do
      tag = language_tag(language: "sv", cldr_locale_name: :sv)
      assert Cldr.Collation.compare("\u00E5", "z", locale: tag) == :gt
      assert Cldr.Collation.compare("\u00E4", "z", locale: tag) == :gt
      assert Cldr.Collation.compare("\u00F6", "z", locale: tag) == :gt
    end

    test "LanguageTag sort matches string locale sort for Spanish" do
      tag = language_tag(language: "es")
      input = ["obra", "\u00F1o\u00F1o", "nube"]

      tag_result = Cldr.Collation.sort(input, locale: tag)
      string_result = Cldr.Collation.sort(input, locale: "es")

      assert tag_result == string_result
    end

    test "LanguageTag sort matches string locale sort for Danish" do
      tag = language_tag(language: "da", cldr_locale_name: :da)
      input = ["\u00E5l", "\u00E6l", "\u00F8l", "zl"]

      tag_result = Cldr.Collation.sort(input, locale: tag)
      string_result = Cldr.Collation.sort(input, locale: "da")

      assert tag_result == string_result
    end
  end

  # ===================================================================
  # Backend from LanguageTag
  # ===================================================================

  describe "backend resolution from LanguageTag" do
    test "tag with populated backend does not raise" do
      tag = language_tag(backend: SomeApp.Cldr)
      # Should work fine — the backend is extracted but currently
      # only used for future CLDR integration; collation still works
      assert Cldr.Collation.compare("a", "b", locale: tag) == :lt
    end

    test "tag backend is preferred over :cldr_backend option" do
      tag = language_tag(backend: SomeApp.Cldr)
      # Passing :cldr_backend in extra options should not cause errors
      # even when tag already has a backend
      assert Cldr.Collation.compare("a", "b",
               locale: tag, cldr_backend: AnotherApp.Cldr) == :lt
    end

    test "tag without backend still works with :cldr_backend option" do
      tag = language_tag()
      assert Cldr.Collation.compare("a", "b",
               locale: tag, cldr_backend: SomeApp.Cldr) == :lt
    end

    test ":cldr_backend option does not leak into Options struct" do
      tag = language_tag(backend: SomeApp.Cldr)
      # The :cldr_backend should be stripped before Options.new
      # This verifies no KeyError or unexpected field warnings
      result = Cldr.Collation.sort(["b", "a"], locale: tag)
      assert result == ["a", "b"]
    end
  end

  # ===================================================================
  # Error handling
  # ===================================================================

  describe "invalid locale values raise ArgumentError" do
    test "non-string non-struct locale raises" do
      assert_raise ArgumentError, fn ->
        Cldr.Collation.compare("a", "b", locale: 42)
      end
    end
  end
end
