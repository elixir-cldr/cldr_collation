defmodule Cldr.Collation.ImplicitWeights do
  @moduledoc """
  Computes implicit collation elements for codepoints not in the DUCET/CLDR allkeys table.

  The UCA defines an algorithm for computing implicit weights for:
  - CJK Unified Ideographs (Han characters)
  - Hangul syllables (decomposed algorithmically)
  - Unassigned codepoints

  See UTS #10 Section 10.1 for the implicit weight computation.

  """

  import Bitwise
  alias Cldr.Collation.Element

  # CJK Unified Ideograph ranges
  # Core CJK block
  @cjk_unified_start 0x4E00
  @cjk_unified_end 0x9FFF

  # CJK Compatibility Ideographs
  @cjk_compat_start 0xF900
  @cjk_compat_end 0xFAFF

  # CJK Extension A
  @cjk_ext_a_start 0x3400
  @cjk_ext_a_end 0x4DBF

  # CJK Extension B
  @cjk_ext_b_start 0x20000
  @cjk_ext_b_end 0x2A6DF

  # CJK Extension C-I and more
  @cjk_ext_c_start 0x2A700
  @cjk_ext_c_end 0x2B81D

  @cjk_ext_d_start 0x2B820
  @cjk_ext_d_end 0x2CEAD

  @cjk_ext_e_start 0x2CEB0
  @cjk_ext_e_end 0x2EBE0

  @cjk_ext_f_start 0x2EBF0
  @cjk_ext_f_end 0x2EE5D

  @cjk_ext_g_start 0x30000
  @cjk_ext_g_end 0x3134A

  @cjk_ext_h_start 0x31350
  @cjk_ext_h_end 0x33479

  # Hangul syllable range
  @hangul_start 0xAC00
  @hangul_end 0xD7A3

  # Hangul jamo constants
  @sbase 0xAC00
  @lbase 0x1100
  @vbase 0x1161
  @tbase 0x11A7
  @vcount 21
  @tcount 28
  # 588
  @ncount @vcount * @tcount
  # Implicit weight bases from UCA
  # The CLDR uses specific base values for each group
  @han_base 0xFB40
  @han_ext_base 0xFB80
  @unassigned_base 0xFBC0

  @doc """
  Check if a codepoint is a CJK Unified Ideograph.

  Covers the core CJK block, all extensions (A through H), compatibility
  ideographs, and specific compatibility ideograph codepoints.

  ### Arguments

  * `cp` - an integer codepoint

  ### Returns

  * `true` if the codepoint is a CJK Unified Ideograph
  * `false` otherwise

  ### Examples

      iex> Cldr.Collation.ImplicitWeights.unified_ideograph?(0x4E00)
      true

      iex> Cldr.Collation.ImplicitWeights.unified_ideograph?(0x0041)
      false

  """
  def unified_ideograph?(cp) do
    (cp >= @cjk_unified_start and cp <= @cjk_unified_end) or
      (cp >= @cjk_ext_a_start and cp <= @cjk_ext_a_end) or
      (cp >= @cjk_ext_b_start and cp <= @cjk_ext_b_end) or
      (cp >= @cjk_ext_c_start and cp <= @cjk_ext_c_end) or
      (cp >= @cjk_ext_d_start and cp <= @cjk_ext_d_end) or
      (cp >= @cjk_ext_e_start and cp <= @cjk_ext_e_end) or
      (cp >= @cjk_ext_f_start and cp <= @cjk_ext_f_end) or
      (cp >= @cjk_ext_g_start and cp <= @cjk_ext_g_end) or
      (cp >= @cjk_ext_h_start and cp <= @cjk_ext_h_end) or
      (cp >= @cjk_compat_start and cp <= @cjk_compat_end) or
      cp in [
        0xFA0E,
        0xFA0F,
        0xFA11,
        0xFA13,
        0xFA14,
        0xFA1F,
        0xFA21,
        0xFA23,
        0xFA24,
        0xFA27,
        0xFA28,
        0xFA29
      ]
  end

  @doc """
  Check if a codepoint is a Hangul syllable.

  Hangul syllables occupy the range U+AC00..U+D7A3.

  ### Arguments

  * `cp` - an integer codepoint

  ### Returns

  * `true` if the codepoint is a Hangul syllable
  * `false` otherwise

  ### Examples

      iex> Cldr.Collation.ImplicitWeights.hangul_syllable?(0xAC00)
      true

      iex> Cldr.Collation.ImplicitWeights.hangul_syllable?(0x0041)
      false

  """
  def hangul_syllable?(cp), do: cp >= @hangul_start and cp <= @hangul_end

  @doc """
  Compute implicit collation elements for a codepoint not in the allkeys table.

  Handles three cases:
  - Hangul syllables: algorithmically decomposed to jamo
  - CJK Unified Ideographs: implicit weight pair from code point value
  - All others: unassigned implicit weight pair

  ### Arguments

  * `cp` - an integer codepoint

  ### Returns

  * `{:hangul_decompose, jamo}` - for Hangul syllables, returns the constituent jamo for table lookup
  * `[%Cldr.Collation.Element{}, %Cldr.Collation.Element{}]` - two implicit CEs for CJK or unassigned codepoints

  ### Examples

      iex> [ce1, ce2] = Cldr.Collation.ImplicitWeights.compute(0x4E00)
      iex> Cldr.Collation.Element.primary(ce1) >= 0xFB40
      true
      iex> Cldr.Collation.Element.secondary(ce2)
      0

  """
  def compute(cp) do
    cond do
      hangul_syllable?(cp) ->
        decompose_hangul(cp)

      unified_ideograph?(cp) ->
        # In CLDR root collation, Han characters use implicit weights
        # based on code point value. The han module can override this
        # with radical-stroke ordering.
        compute_han_implicit(cp)

      true ->
        compute_unassigned(cp)
    end
  end

  @doc """
  Decompose a Hangul syllable into its constituent jamo codepoints.

  Uses the algorithmic decomposition defined in the Unicode Standard
  (Chapter 3, Section 3.12).

  ### Arguments

  * `cp` - an integer codepoint for a Hangul syllable (U+AC00..U+D7A3)

  ### Returns

  A list of 2 or 3 jamo codepoints: `[lead, vowel]` or `[lead, vowel, trail]`.

  ### Examples

      iex> Cldr.Collation.ImplicitWeights.decompose_hangul_to_jamo(0xAC00)
      [0x1100, 0x1161]

      iex> Cldr.Collation.ImplicitWeights.decompose_hangul_to_jamo(0xAC01)
      [0x1100, 0x1161, 0x11A8]

  """
  def decompose_hangul_to_jamo(cp) do
    sindex = cp - @sbase
    lindex = div(sindex, @ncount)
    vindex = div(rem(sindex, @ncount), @tcount)
    tindex = rem(sindex, @tcount)

    l = @lbase + lindex
    v = @vbase + vindex

    if tindex > 0 do
      t = @tbase + tindex
      [l, v, t]
    else
      [l, v]
    end
  end

  defp decompose_hangul(cp) do
    # Hangul syllables decompose to jamo
    # Each jamo should be looked up in the table
    # For implicit weights, we compute based on the decomposition
    jamo = decompose_hangul_to_jamo(cp)

    # Return marker indicating Hangul decomposition needed
    {:hangul_decompose, jamo}
  end

  defp compute_han_implicit(cp) do
    # Core CJK and Extension A use one base, others use another
    base =
      if (cp >= @cjk_unified_start and cp <= @cjk_unified_end) or
           (cp >= @cjk_ext_a_start and cp <= @cjk_ext_a_end) do
        @han_base
      else
        @han_ext_base
      end

    compute_implicit_pair(cp, base)
  end

  defp compute_unassigned(cp) do
    compute_implicit_pair(cp, @unassigned_base)
  end

  defp compute_implicit_pair(cp, base) do
    aaaa = base + (cp >>> 15)
    bbbb = (cp &&& 0x7FFF) ||| 0x8000

    [
      Element.new(aaaa, 0x0020, 0x0002),
      Element.new(bbbb, 0x0000, 0x0000)
    ]
  end
end
