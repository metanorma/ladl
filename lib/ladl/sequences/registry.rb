# frozen_string_literal: true

module Ladl
  module Sequences
    # The default labeling sequences a LADL-compliant runtime must
    # provide (MN 112 "NumericSequence"): left-to-right decimal, Roman,
    # alphabetic, Cyrillic, Greek, Chinese, Japanese and Korean numeral
    # sequences; right-to-left Arabic and Hebrew numeral sequences.
    module Registry
      CYRILLIC_UPPER = %w[А Б В Г Д Е Ж З И Й К Л М Н О П Р С Т У Ф Х Ц Ч Ш Щ Ъ Ы Ь Э Ю Я].freeze
      CYRILLIC_LOWER = CYRILLIC_UPPER.map(&:downcase).freeze
      GREEK_UPPER = %w[Α Β Γ Δ Ε Ζ Η Θ Ι Κ Λ Μ Ν Ξ Ο Π Ρ Σ Τ Υ Φ Χ Ψ Ω].freeze
      GREEK_LOWER = GREEK_UPPER.map(&:downcase).freeze
      HEBREW = %w[א ב ג ד ה ו ז ח ט י כ ל מ נ ס ע פ צ ק ר ש ת].freeze

      module_function

      # Default sequences by instance name, built fresh on each call so
      # callers cannot mutate the shared registry.
      def defaults
        numeric = lambda do |format|
          Ladl::NumericSequence.new(initial_value: 1, increment: 1, format: format)
        end
        arabic_indic_sequence = lambda do
          Ladl::NumericSequence.new(
            initial_value: 1, increment: 1, format: "arabic_indic",
            char_direction: "rtl"
          )
        end
        chars = lambda do |characters|
          Ladl::CharacterSequence.new(
            characters: characters, expansion_rule: "prepend_prefix"
          )
        end

        {
          "DecimalNumericSequence" => numeric.call("decimal"),
          "ArabicNumericSequence" => numeric.call("arabic_indic"),
          "ArabicIndicNumericSequence" => arabic_indic_sequence.call,
          "RomanUpperNumericSequence" => numeric.call("roman_upper"),
          "RomanLowerNumericSequence" => numeric.call("roman_lower"),
          "AlphaUpperNumericSequence" => numeric.call("alpha_upper"),
          "AlphaLowerNumericSequence" => numeric.call("alpha_lower"),
          "ChineseNumericSequence" => numeric.call("chinese"),
          "JapaneseNumericSequence" => numeric.call("japanese"),
          "KoreanNumericSequence" => numeric.call("korean"),
          "CyrillicUpperCharacterSequence" => chars.call(CYRILLIC_UPPER),
          "CyrillicLowerCharacterSequence" => chars.call(CYRILLIC_LOWER),
          "GreekUpperCharacterSequence" => chars.call(GREEK_UPPER),
          "GreekLowerCharacterSequence" => chars.call(GREEK_LOWER),
          "HebrewNumericSequence" => chars.call(HEBREW),
        }
      end

      # Looks up a sequence by instance name in the default registry.
      def lookup(name)
        defaults[name]
      end
    end
  end
end
