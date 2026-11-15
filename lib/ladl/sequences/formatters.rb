# frozen_string_literal: true

module Ladl
  module Sequences
    # Labeling formats: renders a 1-based numeric value in a particular
    # alphanumeric system (MN 112 "labeling format").
    module Formatters
      ROMAN_PAIRS = [
        [1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"],
        [90, "XC"], [50, "L"], [40, "XL"], [10, "X"], [9, "IX"],
        [5, "V"], [4, "IV"], [1, "I"],
      ].freeze

      UNITS = {
        "chinese" => %w[零 一 二 三 四 五 六 七 八 九],
        "japanese" => %w[零 一 二 三 四 五 六 七 八 九],
        "korean" => %w[영 일 이 삼 사 오 육 칠 팔 구],
      }.freeze
      SMALL_TEN = { "chinese" => "十", "japanese" => "十", "korean" => "십" }.freeze
      SMALL_HUNDRED = { "chinese" => "百", "japanese" => "百", "korean" => "백" }.freeze
      SMALL_THOUSAND = { "chinese" => "千", "japanese" => "千", "korean" => "천" }.freeze

      module_function

      # Renders the 1-based integer `number` in the given format.
      #
      # @param format [String] decimal, roman_upper, roman_lower,
      #   alpha_upper, alpha_lower, arabic_indic, chinese, japanese,
      #   korean
      # @param number [Integer] a positive 1-based value
      # @raise [Ladl::Error] on unknown format or non-positive value
      def format(format, number)
        raise Ladl::Error, "sequence value must be positive, got #{number}" if number.to_i < 1

        case format
        when "decimal" then number.to_s
        when "roman_upper" then roman(number)
        when "roman_lower" then roman(number).downcase
        when "alpha_upper" then alpha(number)
        when "alpha_lower" then alpha(number).downcase
        when "arabic_indic" then arabic_indic(number)
        when "chinese", "japanese", "korean" then east_asian(format, number)
        else
          raise Ladl::Error, "unknown labeling format: #{format.inspect}"
        end
      end

      def roman(number)
        result = +""
        n = number
        ROMAN_PAIRS.each do |value, letters|
          while n >= value
            result << letters
            n -= value
          end
        end
        result
      end

      # Spreadsheet-style letters: 1 -> A ... 26 -> Z, 27 -> AA.
      def alpha(number)
        Ladl::Sequences.digits(number, 26)
          .map { |d| (64 + d).chr }
          .join
      end

      def arabic_indic(number)
        number.to_s.tr("0123456789", "٠١٢٣٤٥٦٧٨٩")
      end

      # East-Asian numerals up to 9999: compound tens, hundreds and
      # thousands (十, 百, 千 / 십, 백, 천). The leading unit is dropped
      # before the tens marker only (十, not 一十), while hundreds and
      # thousands keep the unit (一百, 一千) per formal CJK numbering.
      # Internal zeros are not marked (108 -> 一百八), matching
      # document-numbering practice.
      def east_asian(format, number)
        units = UNITS.fetch(format)
        thousands, rest_thousands = number.divmod(1000)
        hundreds, rest_hundreds = rest_thousands.divmod(100)
        tens, ones = rest_hundreds.divmod(10)

        out = +""
        out << compound(units, thousands, SMALL_THOUSAND.fetch(format),
          drop_single_unit: false) if thousands.positive?
        out << compound(units, hundreds, SMALL_HUNDRED.fetch(format),
          drop_single_unit: false) if hundreds.positive?
        out << compound(units, tens, SMALL_TEN.fetch(format),
          drop_single_unit: true) if tens.positive?
        out << units[ones] if ones.positive?
        out
      end

      def compound(units, count, marker, drop_single_unit: true)
        prefix = if count == 1 && drop_single_unit
          ""
        else
          units[count]
        end
        "#{prefix}#{marker}"
      end
    end
  end
end
