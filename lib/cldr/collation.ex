defmodule Cldr.Collation do
  @moduledoc """
  Implements the Unicode Cldr.Collation Algorithm (UCA) as extended by CLDR.

  Cldr.Collation is the general term for the process and function of
  determining the sorting order of strings of characters, for example for
  lists of strings presented to users, or in databases for sorting and selecting
  records.

  Cldr.Collation varies by language, by application (some languages use special
  phonebook sorting), and other criteria (for example, phonetic vs. visual).

  CLDR provides collation data for many languages and styles. The data
  supports not only sorting but also language-sensitive searching and grouping
  under index headers. All CLDR collations are based on the [UCA] default order,
  with common modifications applied in the CLDR root collation, and further
  tailored for language and style as needed.

  ## Basic Usage

      # Compare two strings
      iex> Cldr.Collation.compare("café", "cafe")
      :gt

      # Sort a list of strings
      iex> Cldr.Collation.sort(["café", "cafe", "Cafe"])
      ["cafe", "Cafe", "café"]

      # Generate a sort key
      iex> Cldr.Collation.sort_key("hello")
      <<36, 196, 36, 83, 37, 40, 37, 40, 37, 152, 0, 0, 0, 32, 0, 32, 0, 32, 0, 32, 0,
        32, 0, 0, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2>>

      # With options
      iex> Cldr.Collation.compare("a", "A", strength: :secondary)
      :eq

      # From BCP47 locale
      iex> Cldr.Collation.compare("a", "A", locale: "en-u-ks-level2")
      :eq

  ## Cldr.Collation Options

  All BCP47 -u- extension collation keys are supported:

  - `strength` - `:primary`, `:secondary`, `:tertiary` (default), `:quaternary`, `:identical`
  - `alternate` - `:non_ignorable` (default), `:shifted`
  - `backwards` - `false` (default), `true` - reverse secondary weights (French)
  - `normalization` - `false` (default), `true` - NFD normalize input
  - `case_level` - `false` (default), `true` - insert case-only level
  - `case_first` - `false` (default), `:upper`, `:lower`
  - `numeric` - `false` (default), `true` - numeric string comparison
  - `reorder` - `[]` (default), list of script code atoms
  - `max_variable` - `:punct` (default), `:space`, `:symbol`, `:currency`
  - `ignore_accents` - `true` to ignore accent differences (sets strength to primary)
  - `ignore_case` - `true` to ignore case differences (sets strength to secondary)
  - `ignore_punctuation` - `true` to ignore punctuation and whitespace (sets alternate to shifted)
  - `casing` - `:sensitive`, `:insensitive` (convenience alias, compatible with `ex_cldr_collation`)
  - `backend` - `:default` (NIF if available), `:nif`, `:elixir`

  ## NIF Backend

  An optional NIF backend using ICU4C is available for high-performance collation.
  When compiled, it is used automatically for comparisons that only use
  ICU-configurable attributes (strength, backwards, alternate, case_first,
  case_level, normalization, numeric, reorder). Options requiring locale
  tailoring or non-default max_variable use the pure Elixir backend.

  To enable the NIF backend, either set the environment variable:

      CLDR_COLLATION_NIF=true mix compile

  Or add to your `config.exs` (must be `config.exs`, not `runtime.exs`,
  since it is evaluated at compile time):

      config :ex_cldr_collation, :nif, true

  Requires ICU system libraries (`libicu` or `icucore` on macOS).

  """

  alias Cldr.Collation.{
    FastLatin,
    ImplicitWeights,
    Nif,
    Normalizer,
    Options,
    Reorder,
    SortKey,
    Table,
    Variable
  }

  @doc """
  Compare two strings using the CLDR collation algorithm.

  ### Arguments

  * `string_a` - the first string to compare
  * `string_b` - the second string to compare
  * `options` - a keyword list of collation options

  ### Options

  * `:strength` - comparison level: `:primary`, `:secondary`, `:tertiary` (default), `:quaternary`, or `:identical`
  * `:alternate` - variable weight handling: `:non_ignorable` (default) or `:shifted`
  * `:backwards` - reverse secondary weights for French sorting: `false` (default) or `true`
  * `:normalization` - NFD normalize input: `false` (default) or `true`
  * `:case_level` - insert case-only comparison level: `false` (default) or `true`
  * `:case_first` - case ordering: `false` (default), `:upper`, or `:lower`
  * `:numeric` - numeric string comparison: `false` (default) or `true`
  * `:reorder` - list of script code atoms to reorder: `[]` (default)
  * `:max_variable` - variable weight boundary: `:punct` (default), `:space`, `:symbol`, or `:currency`
  * `:locale` - a BCP47 locale string (e.g., `"en-u-ks-level2"`) or a `Cldr.LanguageTag` struct (when `ex_cldr` is available). When `ex_cldr` is loaded and a string is provided, it is parsed via `Cldr.Locale.canonical_language_tag/2` using the default CLDR backend.
  * `:cldr_backend` - a CLDR backend module to use for locale parsing (e.g., `MyApp.Cldr`). Only used when `:locale` is a string. Defaults to `Cldr.default_backend!()`.
  * `:ignore_accents` - `true` to ignore accent differences (sets `strength: :primary`). Explicit `:strength` takes precedence.
  * `:ignore_case` - `true` to ignore case differences (sets `strength: :secondary`). Explicit `:strength` takes precedence.
  * `:ignore_punctuation` - `true` to ignore punctuation and whitespace (sets `alternate: :shifted`). Explicit `:strength` or `:alternate` take precedence.
  * `:casing` - `:sensitive` or `:insensitive` (convenience alias for strength, compatible with `ex_cldr_collation`)
  * `:backend` - `:default` (NIF if available), `:nif` (require NIF), or `:elixir` (pure Elixir)

  ### Returns

  * `:lt` - if `string_a` sorts before `string_b`
  * `:eq` - if `string_a` and `string_b` are equal at the given strength
  * `:gt` - if `string_a` sorts after `string_b`

  ### Examples

      iex> Cldr.Collation.compare("cafe", "café")
      :lt

      iex> Cldr.Collation.compare("a", "A", strength: :secondary)
      :eq

      iex> Cldr.Collation.compare("a", "A", casing: :insensitive)
      :eq

  """
  def compare(string_a, string_b, options \\ []) do
    options = resolve_options(options)

    if use_nif?(options) do
      Nif.nif_compare(string_a, string_b, options)
    else
      key_a = sort_key(string_a, options)
      key_b = sort_key(string_b, options)

      cond do
        key_a < key_b -> :lt
        key_a > key_b -> :gt
        true -> :eq
      end
    end
  end

  @doc """
  Generate a binary sort key for the given input.

  Sort keys can be compared directly with `<`, `>`, `==` for ordering.
  This is efficient when the same strings need to be compared multiple times.

  ### Arguments

  * `input` - a UTF-8 string or a list of integer codepoints
  * `options` - a keyword list of collation options, or a `%Cldr.Collation.Options{}` struct

  ### Options

  Accepts the same options as `compare/3`.

  ### Returns

  A binary sort key that can be compared with standard binary comparison operators.

  ### Examples

      iex> key_a = Cldr.Collation.sort_key("cafe")
      iex> key_b = Cldr.Collation.sort_key("café")
      iex> key_a < key_b
      true

      iex> Cldr.Collation.sort_key("hello") == Cldr.Collation.sort_key("hello")
      true

  """
  def sort_key(input, options \\ [])

  def sort_key(input, options) when is_list(options) do
    sort_key(input, resolve_options(options))
  end

  def sort_key(string, %Options{} = options) when is_binary(string) do
    ensure_loaded()
    codepoints = Normalizer.normalize_to_codepoints(string, options.normalization)
    build_sort_key(codepoints, options, string)
  end

  def sort_key(codepoints, %Options{} = options) when is_list(codepoints) do
    ensure_loaded()

    codepoints =
      if options.normalization do
        codepoints
        |> List.to_string()
        |> Normalizer.normalize_to_codepoints(true)
      else
        codepoints
      end

    build_sort_key(codepoints, options, nil)
  end

  defp build_sort_key(codepoints, options, original_string) do
    elements = produce_collation_elements(codepoints, options)

    max_var_primary = Options.max_variable_primary(options)
    processed = Variable.process(elements, options.alternate, max_var_primary)

    processed =
      case Reorder.build_mapping(options.reorder) do
        nil ->
          processed

        mapping_fn ->
          Enum.map(processed, fn {{p, s, t, v}, q} ->
            {{mapping_fn.(p), s, t, v}, q}
          end)
      end

    SortKey.build(processed, options, original_string)
  end

  @doc """
  Sort a list of strings using the CLDR collation algorithm.

  ### Arguments

  * `strings` - a list of UTF-8 strings to sort
  * `options` - a keyword list of collation options

  ### Options

  Accepts the same options as `compare/3`.

  ### Returns

  A new list of strings sorted according to the CLDR collation rules.

  ### Examples

      iex> Cldr.Collation.sort(["café", "cafe", "Cafe"])
      ["cafe", "Cafe", "café"]

      iex> Cldr.Collation.sort(["б", "а", "в"])
      ["а", "б", "в"]

  """
  def sort(strings, options \\ []) do
    options = resolve_options(options)

    if use_nif?(options) do
      Enum.sort(strings, fn a, b ->
        Nif.nif_compare(a, b, options) in [:lt, :eq]
      end)
    else
      strings
      |> Enum.map(fn s -> {sort_key(s, options), s} end)
      |> Enum.sort_by(fn {key, _s} -> key end)
      |> Enum.map(fn {_key, s} -> s end)
    end
  end

  @doc """
  Ensure the collation tables are loaded into persistent term storage.

  When the NIF backend is available and all options are NIF-compatible,
  the collation tables are not needed and are not loaded automatically.
  The tables are only loaded on demand when the Elixir backend is used
  (for `sort_key/2`, locale tailoring, or when `backend: :elixir` is
  specified).

  This function can be called explicitly to pre-warm the tables at
  application startup if you know you will use the Elixir backend.

  ### Returns

  * `:ok` - tables are loaded and ready

  ### Examples

      iex> Cldr.Collation.ensure_loaded()
      :ok

  """
  def ensure_loaded do
    Table.ensure_loaded()
  end

  # Internal: produce collation elements from codepoints

  defp produce_collation_elements(codepoints, options) do
    overlay = options.tailoring

    if options.numeric do
      produce_with_numeric(codepoints, options)
    else
      produce_standard(codepoints, overlay)
    end
  end

  defp produce_standard(codepoints, overlay) do
    do_produce(codepoints, [], overlay)
  end

  defp do_produce([], acc, _overlay), do: Enum.reverse(acc) |> List.flatten()

  # Fast path for Basic Latin / Latin Extended-A codepoints without tailoring.
  # Skips contraction checking and discontiguous match for characters that
  # are known to have direct single-codepoint mappings (no contractions,
  # CCC = 0).
  defp do_produce([cp | rest], acc, nil) when cp < 0x0180 do
    case FastLatin.lookup(cp) do
      nil ->
        do_produce_full([cp | rest], acc, nil)

      elements ->
        do_produce(rest, [elements | acc], nil)
    end
  end

  defp do_produce(codepoints, acc, overlay) do
    do_produce_full(codepoints, acc, overlay)
  end

  defp do_produce_full(codepoints, acc, overlay) do
    case Table.longest_match_with_overlay(codepoints, overlay) do
      {matched, elements, remaining} when is_list(elements) ->
        # After matching, check for discontiguous contractions with following
        # combining marks (UCA S2.1.1)
        {final_elements, final_remaining} =
          try_discontiguous_match(matched, elements, remaining)

        do_produce(final_remaining, [final_elements | acc], overlay)

      {:unmapped, cp, remaining} ->
        elements = resolve_unmapped(cp)
        # Also check for discontiguous contractions starting from unmapped char
        {final_elements, final_remaining} =
          try_discontiguous_match([cp], elements, remaining)

        do_produce(final_remaining, [final_elements | acc], overlay)

      :done ->
        Enum.reverse(acc) |> List.flatten()
    end
  end

  # UCA S2.1.1: Discontiguous contraction matching
  # After matching a starter S, check if any following combining marks
  # can form a contraction with S, skipping blocked combining marks.
  #
  # A combining mark C at position i is "blocked" if there exists
  # another combining mark B between S and C such that ccc(B) >= ccc(C).
  defp try_discontiguous_match(matched_cps, elements, remaining) do
    case remaining do
      [] ->
        {elements, remaining}

      _ ->
        # Collect following combining marks
        {combiners, rest} = collect_combining(remaining, [])

        if combiners == [] do
          {elements, remaining}
        else
          # Try to extend the match with unblocked combining marks
          {new_elements, _consumed, unconsumed} =
            extend_with_combiners(matched_cps, elements, combiners)

          # Reconstruct remaining: unconsumed combiners + rest
          new_remaining = unconsumed ++ rest
          {new_elements, new_remaining}
        end
    end
  end

  # Collect consecutive combining characters (ccc > 0)
  defp collect_combining([cp | rest], acc) do
    ccc = combining_class(cp)

    if ccc > 0 do
      collect_combining(rest, [{cp, ccc} | acc])
    else
      {Enum.reverse(acc), [cp | rest]}
    end
  end

  defp collect_combining([], acc), do: {Enum.reverse(acc), []}

  # Try to match the base sequence + each unblocked combining mark
  defp extend_with_combiners(base_cps, base_elements, combiners) do
    {final_elements, consumed_set, _last_ccc, _current_base} =
      Enum.reduce(combiners, {base_elements, MapSet.new(), 0, base_cps}, fn
        {cp, ccc}, {elems, consumed, last_ccc, current_base} ->
          # Check if this combining mark is blocked
          if ccc > 0 and (last_ccc == 0 or ccc > last_ccc) do
            # Not blocked - try to extend the match
            candidate = current_base ++ [cp]

            case Table.lookup(candidate) do
              {:ok, new_elements} ->
                {new_elements, MapSet.put(consumed, cp), ccc, candidate}

              :unmapped ->
                {elems, consumed, ccc, current_base}
            end
          else
            # Blocked - skip
            {elems, consumed, last_ccc, current_base}
          end
      end)

    unconsumed =
      Enum.reject(combiners, fn {cp, _ccc} -> MapSet.member?(consumed_set, cp) end)
      |> Enum.map(fn {cp, _ccc} -> cp end)

    {final_elements, consumed_set, unconsumed}
  end

  # Get the canonical combining class for a codepoint
  defp combining_class(cp) do
    Unicode.CanonicalCombiningClass.combining_class(cp) || 0
  end

  defp produce_with_numeric(codepoints, _options) do
    pairs = collect_ce_pairs(codepoints, [])
    Cldr.Collation.Numeric.process_elements(pairs)
  end

  defp collect_ce_pairs([], acc), do: Enum.reverse(acc)

  defp collect_ce_pairs(codepoints, acc) do
    case Table.longest_match(codepoints) do
      {matched, elements, remaining} when is_list(elements) ->
        collect_ce_pairs(remaining, [{matched, elements} | acc])

      {:unmapped, cp, remaining} ->
        elements = resolve_unmapped(cp)
        collect_ce_pairs(remaining, [{[cp], elements} | acc])

      :done ->
        Enum.reverse(acc)
    end
  end

  defp resolve_unmapped(cp) do
    case ImplicitWeights.compute(cp) do
      {:hangul_decompose, jamo} ->
        Enum.flat_map(jamo, fn j ->
          case Table.lookup(j) do
            {:ok, elements} -> elements
            :unmapped -> ImplicitWeights.compute(j)
          end
        end)

      elements when is_list(elements) ->
        elements
    end
  end

  defp resolve_options(options) when is_list(options) do
    case Keyword.get(options, :locale) do
      nil ->
        Options.new(options)

      locale when is_binary(locale) ->
        rest = Keyword.delete(options, :locale)

        case parse_locale_string(locale, rest) do
          {:cldr, tag, extra} ->
            options_from_language_tag(tag, extra)

          {:builtin, locale_string, extra} ->
            Options.from_locale(locale_string) |> struct(extra)
        end

      locale ->
        options_from_language_tag(locale, Keyword.delete(options, :locale))
    end
  end

  defp resolve_options(%Options{} = options), do: options

  # When ex_cldr is available, parse a locale string into a Cldr.LanguageTag
  # using the configured backend for full validation and canonicalization.
  # Falls back to the built-in parser when ex_cldr is not loaded or no
  # backend is available.
  defp parse_locale_string(locale, extra_options) do
    with true <- Code.ensure_loaded?(Cldr.Locale),
         {:ok, backend} <- cldr_backend(extra_options),
         {:ok, tag} <- Cldr.Locale.canonical_language_tag(locale, backend) do
      {:cldr, tag, Keyword.delete(extra_options, :cldr_backend)}
    else
      _ -> {:builtin, locale, extra_options}
    end
  end

  # Resolve the CLDR backend from options or the configured default.
  defp cldr_backend(options) do
    case Keyword.get(options, :cldr_backend) do
      nil ->
        try do
          {:ok, Cldr.default_backend!()}
        rescue
          _ -> :error
        end

      backend when is_atom(backend) ->
        {:ok, backend}
    end
  end

  # Extract collation options from a Cldr.LanguageTag struct.
  # The tag's `locale` field contains the parsed -u- extension data
  # as a %Cldr.LanguageTag.U{} struct with atom keys and validated values.
  #
  # Locale resolution uses `cldr_locale_name` first, falling back to
  # `language`, to derive locale defaults and tailoring rules.
  #
  # When the tag has a populated `:backend` field, it is used as the CLDR
  # backend; otherwise the `:cldr_backend` keyword option is consulted.
  defp options_from_language_tag(tag, extra_options) do
    unless Code.ensure_loaded?(Cldr.LanguageTag) and is_struct(tag, Cldr.LanguageTag) do
      raise ArgumentError,
            "invalid :locale option #{inspect(tag)}, expected a BCP47 locale string" <>
              if(Code.ensure_loaded?(Cldr.LanguageTag),
                do: " or a Cldr.LanguageTag struct",
                else: ""
              )
    end

    alias Cldr.Collation.Tailoring
    alias Cldr.Collation.Tailoring.LocaleDefaults

    u = tag.locale

    # Extract U extension options from the tag
    u_options =
      []
      |> maybe_put(:strength, u_strength(u))
      |> maybe_put(:alternate, u_alternate(u))
      |> maybe_put(:backwards, u_bool(u, :col_backwards))
      |> maybe_put(:normalization, u_bool(u, :col_normalization))
      |> maybe_put(:case_level, u_bool(u, :col_case_level))
      |> maybe_put(:case_first, u_case_first(u))
      |> maybe_put(:numeric, u_bool(u, :col_numeric))
      |> maybe_put(:reorder, u_reorder(u))
      |> maybe_put(:max_variable, u_max_variable(u))
      |> maybe_put(:type, u_collation_type(u))

    # Resolve the language for locale defaults and tailoring.
    # Prefer cldr_locale_name (e.g. :da), fall back to language (e.g. "da").
    language = tag_language(tag)
    locale_defaults = LocaleDefaults.options_for(language)

    # Determine collation type: U extension > extra options > locale default
    type =
      Keyword.get(u_options, :type) ||
        Keyword.get(extra_options, :type) ||
        LocaleDefaults.default_type(language)

    # Load tailoring overlay if available
    {tailoring_overlay, tailoring_option_overrides} =
      case Tailoring.get_tailoring(language, type) do
        {overlay, overrides} -> {overlay, overrides}
        nil -> {nil, []}
      end

    # Strip :cldr_backend from extra options — not an Options struct field
    extra_options = Keyword.delete(extra_options, :cldr_backend)

    # Build options with precedence:
    # extra keyword options > U extension > locale defaults > tailoring overrides > struct defaults
    Options.new()
    |> struct(tailoring_option_overrides)
    |> struct(locale_defaults)
    |> struct(u_options)
    |> struct(Keyword.delete(extra_options, :type))
    |> Map.put(:type, type)
    |> Map.put(:tailoring, tailoring_overlay)
  end

  # Resolve a language string from a Cldr.LanguageTag for locale defaults
  # and tailoring lookup. Prefers cldr_locale_name, falls back to language.
  defp tag_language(tag) do
    alias Cldr.Collation.Tailoring.LocaleDefaults

    cond do
      is_atom(tag.cldr_locale_name) and not is_nil(tag.cldr_locale_name) ->
        tag.cldr_locale_name |> to_string() |> LocaleDefaults.extract_language()

      is_binary(tag.language) ->
        LocaleDefaults.extract_language(tag.language)

      true ->
        "und"
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp u_strength(u), do: u_field(u, :col_strength)
  defp u_alternate(u), do: u_field(u, :col_alternate)
  defp u_case_first(u), do: u_field(u, :col_case_first)
  defp u_collation_type(u), do: u_field(u, :collation)
  defp u_max_variable(u), do: u_field(u, :kv)
  defp u_reorder(u), do: u_field(u, :col_reorder)

  # U struct uses :yes/:no for boolean fields
  defp u_bool(u, field) do
    case u_field(u, field) do
      :yes -> true
      :no -> false
      nil -> nil
    end
  end

  # Safely access a field from either a %Cldr.LanguageTag.U{} struct or a plain map.
  defp u_field(u, field) when is_struct(u), do: Map.get(u, field)
  defp u_field(_u, _field), do: nil

  # Determine whether to use the NIF backend for the given options.
  # Returns true when:
  #   - backend is :nif (raises if NIF unavailable)
  #   - backend is :default, NIF is available, and options are NIF-compatible
  # Returns false when:
  #   - backend is :elixir
  #   - backend is :default and NIF is unavailable or options are incompatible
  defp use_nif?(%Options{backend: :elixir}), do: false

  defp use_nif?(%Options{backend: :nif} = options) do
    unless Nif.available?() do
      raise RuntimeError,
            "NIF collation backend requested but not available. " <>
              "Compile with CLDR_COLLATION_NIF=true or set `config :ex_cldr_collation, :nif, true` " <>
              "in config.exs, and ensure ICU libraries are installed."
    end

    unless Options.nif_compatible?(options) do
      raise ArgumentError,
            "NIF collation backend does not support the given options. " <>
              "Options requiring tailoring, non-default max_variable, or " <>
              "unrecognized reorder codes are not supported. " <>
              "Use backend: :elixir or backend: :default."
    end

    true
  end

  defp use_nif?(%Options{backend: :default} = options) do
    Nif.available?() and Options.nif_compatible?(options)
  end
end
