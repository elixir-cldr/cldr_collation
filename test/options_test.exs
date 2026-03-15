defmodule Cldr.Collation.OptionsTest do
  use ExUnit.Case

  alias Cldr.Collation.Options

  describe "new/1" do
    test "creates default options" do
      opts = Options.new()
      assert opts.strength == :tertiary
      assert opts.alternate == :non_ignorable
      assert opts.backwards == false
      assert opts.normalization == false
      assert opts.case_level == false
      assert opts.case_first == false
      assert opts.numeric == false
      assert opts.reorder == []
      assert opts.max_variable == :punct
      assert opts.type == :standard
    end

    test "accepts keyword options" do
      opts = Options.new(strength: :primary, backwards: true)
      assert opts.strength == :primary
      assert opts.backwards == true
    end
  end

  describe "from_locale/1" do
    test "parses strength" do
      opts = Options.from_locale("en-u-ks-level1")
      assert opts.strength == :primary

      opts = Options.from_locale("en-u-ks-level2")
      assert opts.strength == :secondary

      opts = Options.from_locale("en-u-ks-identic")
      assert opts.strength == :identical
    end

    test "parses alternate" do
      opts = Options.from_locale("en-u-ka-shifted")
      assert opts.alternate == :shifted

      opts = Options.from_locale("en-u-ka-noignore")
      assert opts.alternate == :non_ignorable
    end

    test "parses backwards (French accents)" do
      opts = Options.from_locale("fr-u-kb-true")
      assert opts.backwards == true
    end

    test "parses case_first" do
      opts = Options.from_locale("en-u-kf-upper")
      assert opts.case_first == :upper

      opts = Options.from_locale("en-u-kf-lower")
      assert opts.case_first == :lower
    end

    test "parses numeric" do
      opts = Options.from_locale("en-u-kn-true")
      assert opts.numeric == true
    end

    test "parses max_variable" do
      opts = Options.from_locale("en-u-kv-space")
      assert opts.max_variable == :space

      opts = Options.from_locale("en-u-kv-currency")
      assert opts.max_variable == :currency
    end

    test "parses collation type" do
      opts = Options.from_locale("de-u-co-phonebk")
      assert opts.type == :phonebook
    end

    test "parses multiple options" do
      opts = Options.from_locale("en-u-ks-level2-ka-shifted-kn-true")
      assert opts.strength == :secondary
      assert opts.alternate == :shifted
      assert opts.numeric == true
    end

    test "handles locale without -u- extension" do
      opts = Options.from_locale("en")
      assert opts == Options.new()
    end
  end
end
