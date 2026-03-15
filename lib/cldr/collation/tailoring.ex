defmodule Cldr.Collation.Tailoring do
  @moduledoc """
  CLDR locale-specific collation tailoring.

  Parses and applies CLDR tailoring rules that modify the root collation order
  for specific locales. Rules use the ICU/CLDR syntax defined in UTS #35:

  - `&X` — reset position to after character X
  - `&[before N]X` — reset to just before X at level N
  - `<` — primary difference (new letter)
  - `<<` — secondary difference (accent variant)
  - `<<<` — tertiary difference (case variant)
  - `[caseFirst upper]` — option overrides

  Tailoring data is embedded directly from CLDR XML sources, covering common
  European and Asian locales.

  """

  alias Cldr.Collation.{Element, Table}

  # Embedded CLDR tailoring rules per {language, collation_type}.
  # Source: unicode-org/cldr/common/collation/*.xml (CLDR 46)
  @tailorings %{
    {"da", :standard} =>
      "[caseFirst upper]\n&D<<đ<<<Đ<<ð<<<Ð\n&Y<<ü<<<Ü<<ű<<<Ű\n&[before 1]ǀ<æ<<<Æ<<ä<<<Ä<ø<<<Ø<<ö<<<Ö<<ő<<<Ő<å<<<Å<<<aa<<<Aa<<<AA",
    {"de", :phonebook} => "&AE<<ä<<<Ä\n&OE<<ö<<<Ö\n&UE<<ü<<<Ü",
    {"es", :standard} => "&N<ñ<<<Ñ",
    {"es", :traditional} => "&N<ñ<<<Ñ\n&C<ch<<<Ch<<<CH\n&l<ll<<<Ll<<<LL",
    {"sv", :standard} =>
      "&D<<đ<<<Đ<<ð<<<Ð\n&Y<<ü<<<Ü<<ű<<<Ű\n&[before 1]ǀ<å<<<Å<ä<<<Ä<<æ<<<Æ<<ę<<<Ę<ö<<<Ö<<ø<<<Ø<<ő<<<Ő<<œ<<<Œ<<ô<<<Ô",
    {"fi", :standard} =>
      "&D<<đ<<<Đ<<ð<<<Ð\n&Y<<ü<<<Ü<<ű<<<Ű\n&[before 1]ǀ<å<<<Å<ä<<<Ä<<æ<<<Æ<<ę<<<Ę<ö<<<Ö<<ø<<<Ø<<ő<<<Ő<<œ<<<Œ<<ô<<<Ô",
    {"nb", :standard} =>
      "[caseFirst upper]\n&D<<đ<<<Đ<<ð<<<Ð\n&Y<<ü<<<Ü<<ű<<<Ű\n&[before 1]ǀ<æ<<<Æ<<ä<<<Ä<ø<<<Ø<<ö<<<Ö<<ő<<<Ő<å<<<Å<<<aa<<<Aa<<<AA",
    {"nn", :standard} =>
      "[caseFirst upper]\n&D<<đ<<<Đ<<ð<<<Ð\n&Y<<ü<<<Ü<<ű<<<Ű\n&[before 1]ǀ<æ<<<Æ<<ä<<<Ä<ø<<<Ø<<ö<<<Ö<<ő<<<Ő<å<<<Å<<<aa<<<Aa<<<AA",
    {"pl", :standard} =>
      "&A<ą<<<Ą\n&C<ć<<<Ć\n&E<ę<<<Ę\n&L<ł<<<Ł\n&N<ń<<<Ń\n&O<ó<<<Ó\n&S<ś<<<Ś\n&Z<ź<<<Ź<ż<<<Ż",
    {"hr", :standard} =>
      "&C<č<<<Č<ć<<<Ć\n&D<dž<<<Dž<<<DŽ<đ<<<Đ\n&L<lj<<<Lj<<<LJ\n&N<nj<<<Nj<<<NJ\n&S<š<<<Š\n&Z<ž<<<Ž",
    {"tr", :standard} => "&C<ç<<<Ç\n&G<ğ<<<Ğ\n&H<ı<<<I\n&O<ö<<<Ö\n&S<ş<<<Ş\n&U<ü<<<Ü"
  }

  @doc """
  Get a tailoring overlay for the given locale and collation type.

  Parses the CLDR tailoring rules and computes overlay entries that modify
  the root collation table for locale-specific ordering.

  ### Arguments

  * `language` - ISO 639 language code (e.g., `"sv"`, `"de"`, `"es"`)
  * `type` - collation type atom (e.g., `:standard`, `:phonebook`, `:traditional`)

  ### Returns

  * `{overlay, option_overrides}` - a map of `%{[codepoint] => [%Element{}]}` overlay entries
    and a keyword list of option overrides (e.g., `[case_first: :upper]`)
  * `nil` - if no tailoring exists for the given locale and type

  ### Examples

      iex> Cldr.Collation.Table.ensure_loaded()
      iex> {overlay, _opts} = Cldr.Collation.Tailoring.get_tailoring("es", :standard)
      iex> is_map(overlay)
      true

  """
  def get_tailoring(language, type) do
    case Map.get(@tailorings, {language, type}) do
      nil -> nil
      rules_str -> build_tailoring(rules_str)
    end
  end

  @doc """
  List all supported locale/type combinations.

  ### Returns

  A list of `{language, type}` tuples.

  ### Examples

      iex> locales = Cldr.Collation.Tailoring.supported_locales()
      iex> {"es", :standard} in locales
      true

  """
  def supported_locales do
    Map.keys(@tailorings)
  end

  @doc """
  Parse a CLDR tailoring rule string into a list of operations.

  ### Arguments

  * `rules_str` - a CLDR/ICU tailoring rule string

  ### Returns

  A list of operation tuples:
  * `{:reset, codepoints}` — reset position to after the given character(s)
  * `{:reset_before, level, codepoints}` — reset to before at the given level
  * `{:primary, codepoints}` — primary difference (`<`)
  * `{:secondary, codepoints}` — secondary difference (`<<`)
  * `{:tertiary, codepoints}` — tertiary difference (`<<<`)
  * `{:option, key, value}` — option override

  ### Examples

      iex> ops = Cldr.Collation.Tailoring.parse_rules("&N<ñ<<<Ñ")
      iex> length(ops)
      3

  """
  def parse_rules(rules_str) do
    rules_str
    |> String.split("\n", trim: true)
    |> Enum.flat_map(&parse_rule_line/1)
  end

  # Build tailoring overlay from a rule string
  defp build_tailoring(rules_str) do
    ops = parse_rules(rules_str)

    # Separate option overrides from ordering operations
    {option_ops, ordering_ops} =
      Enum.split_with(ops, fn
        {:option, _, _} -> true
        _ -> false
      end)

    option_overrides =
      Enum.map(option_ops, fn {:option, key, value} -> {key, value} end)

    # Apply ordering operations to build the overlay
    overlay = apply_operations(ordering_ops)

    {overlay, option_overrides}
  end

  # Parse a single rule line
  defp parse_rule_line(line) do
    line = String.trim(line)

    cond do
      String.starts_with?(line, "[caseFirst ") ->
        value = line |> String.trim_leading("[caseFirst ") |> String.trim_trailing("]")

        case value do
          "upper" -> [{:option, :case_first, :upper}]
          "lower" -> [{:option, :case_first, :lower}]
          "off" -> [{:option, :case_first, false}]
          _ -> []
        end

      String.starts_with?(line, "[reorder ") ->
        codes =
          line
          |> String.trim_leading("[reorder ")
          |> String.trim_trailing("]")
          |> String.split()
          |> Enum.map(&String.to_atom/1)

        [{:option, :reorder, codes}]

      String.starts_with?(line, "&") ->
        parse_reset_and_rules(String.trim_leading(line, "&"))

      true ->
        []
    end
  end

  # Parse a reset followed by ordering rules
  defp parse_reset_and_rules(str) do
    # Check for [before N] prefix
    {reset_op, after_reset} =
      case Regex.run(~r/^\[before (\d)\](.+)$/, str) do
        [_, level_str, remainder] ->
          level = String.to_integer(level_str)
          {first_char, rest} = split_first_char_sequence(remainder)
          {{:reset_before, level, first_char}, rest}

        nil ->
          {first_char, rest} = split_first_char_sequence(str)
          {{:reset, first_char}, rest}
      end

    # Parse the ordering rules after the reset
    ordering_ops = parse_ordering_rules(after_reset)

    [reset_op | ordering_ops]
  end

  # Split off the first character/sequence from a rule string
  # Returns {codepoints, remaining_string}
  defp split_first_char_sequence(str) do
    # The reset target could be multiple characters (e.g., "AE" for German phonebook)
    # It ends when we hit an ordering operator (<, <<, <<<)
    case Regex.run(~r/^(.+?)(<<<|<<|<)(.*)$/, str) do
      [_, chars, op, rest] ->
        cps = string_to_codepoints(chars)
        {cps, op <> rest}

      nil ->
        # No ordering operators follow — just a reset
        cps = string_to_codepoints(str)
        {cps, ""}
    end
  end

  # Parse ordering rules: sequences of <char, <<char, <<<char
  defp parse_ordering_rules(""), do: []

  defp parse_ordering_rules(str) do
    # Match operator followed by character(s) until next operator or end
    case Regex.run(~r/^(<<<|<<|<)(.+?)(?=(<<<|<<|<)|$)/, str) do
      [full, op, chars | _] ->
        level =
          case op do
            "<<<" -> :tertiary
            "<<" -> :secondary
            "<" -> :primary
          end

        cps = string_to_codepoints(chars)
        rest = String.trim_leading(str, full)
        [{level, cps} | parse_ordering_rules(rest)]

      nil ->
        []
    end
  end

  # Convert a string to a list of codepoints
  defp string_to_codepoints(str) do
    str
    |> String.trim()
    |> String.to_charlist()
  end

  # Apply parsed operations to produce an overlay map.
  # State tracks the full CE list from the anchor so that multi-char anchors
  # (like AE in German phonebook) produce correct multi-CE expansions.
  defp apply_operations(ops) do
    Table.ensure_loaded()

    {overlay, _state} =
      Enum.reduce(ops, {%{}, nil}, fn op, {overlay, state} ->
        case op do
          {:reset, cps} ->
            elements = lookup_elements(cps)
            {overlay, {:after, elements}}

          {:reset_before, level, cps} ->
            elements = lookup_elements(cps)
            adjusted = adjust_before(elements, level)
            {overlay, {:after, adjusted}}

          {level, cps} when level in [:primary, :secondary, :tertiary] ->
            case state do
              {:after, anchor_elements} ->
                new_elements = compute_tailored_elements(anchor_elements, level)
                new_overlay = Map.put(overlay, cps, new_elements)
                {new_overlay, {:after, new_elements}}

              nil ->
                {overlay, state}
            end

          _ ->
            {overlay, state}
        end
      end)

    overlay
  end

  # Look up the full CE list for a codepoint sequence.
  # For multi-char sequences not in the table, concatenate CEs of individual chars.
  defp lookup_elements(cps) do
    case Table.lookup(cps) do
      {:ok, elements} ->
        elements

      :unmapped ->
        Enum.flat_map(cps, fn cp ->
          case Table.lookup([cp]) do
            {:ok, elems} -> elems
            :unmapped -> [%Element{primary: 0, secondary: 0x0020, tertiary: 0x0002}]
          end
        end)
    end
  end

  # Adjust elements for [before N] — decrement at the appropriate level
  # on the LAST CE's weight at level N
  defp adjust_before(elements, level) do
    {init, [last]} = Enum.split(elements, -1)

    adjusted =
      case level do
        1 -> %{last | primary: last.primary - 1}
        2 -> %{last | secondary: last.secondary - 1}
        3 -> %{last | tertiary: last.tertiary - 1}
      end

    init ++ [adjusted]
  end

  # Compute tailored elements by incrementing at the appropriate level
  # on the last CE in the list. This preserves multi-CE structure for expansions.
  defp compute_tailored_elements(anchor_elements, :primary) do
    {init, [last]} = Enum.split(anchor_elements, -1)
    init ++ [%{last | primary: last.primary + 1, secondary: 0x0020, tertiary: 0x0002}]
  end

  defp compute_tailored_elements(anchor_elements, :secondary) do
    {init, [last]} = Enum.split(anchor_elements, -1)
    init ++ [%{last | secondary: last.secondary + 1, tertiary: 0x0002}]
  end

  defp compute_tailored_elements(anchor_elements, :tertiary) do
    {init, [last]} = Enum.split(anchor_elements, -1)
    init ++ [%{last | tertiary: last.tertiary + 1}]
  end
end
