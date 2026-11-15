# frozen_string_literal: true

module Ladl
  # Sequence evaluation: computes the value of a sequence model at a
  # position, and provides the default sequences required of a
  # LADL-compliant runtime by MN 112.
  module Sequences
    autoload :Registry, "ladl/sequences/registry"
    autoload :Formatters, "ladl/sequences/formatters"

    module_function

    # MN 112 Sequence#value_for_position. `lookup` resolves
    # NumericSequence#base_sequence references; when omitted, base
    # sequences resolve against the default registry only.
    def value_for(sequence, position, lookup: nil)
      case sequence
      when NumericSequence
        numeric_value(sequence, position, lookup)
      when CharacterSequence
        character_value(sequence, position)
      else
        raise Ladl::Error, "unsupported sequence: #{sequence.class}"
      end
    end

    def numeric_value(sequence, position, lookup)
      raw = (sequence.initial_value || 1) + (position - 1) * (sequence.increment || 1)
      if sequence.base_sequence && !sequence.base_sequence.empty?
        base = lookup ? lookup.call(sequence.base_sequence) : Registry.lookup(sequence.base_sequence)
        unless base
          raise Ladl::ResolutionError,
            "sequence references undefined base sequence " \
            "#{sequence.base_sequence.inspect}"
        end
        return value_for(base, raw, lookup: lookup)
      end

      format = sequence.format || "decimal"
      length = sequence.cycle_length
      if length && length.positive?
        digits(raw, length).map { |d| Formatters.format(format, d) }.join
      else
        Formatters.format(format, raw)
      end
    end

    def character_value(sequence, position)
      chars = Array(sequence.characters)
      raise Ladl::SequenceExhaustedError, "sequence has no characters" if chars.empty?

      pos = position - 1
      return chars[pos] if pos >= 0 && pos < chars.size

      expand(chars, pos, sequence)
    end

    def expand(chars, pos, sequence)
      size = chars.size
      cycle = pos / size
      rule = sequence.expansion_rule
      case rule
      when "repeat_label"
        chars[pos % size]
      when "prepend_prefix"
        prefixes = prefixes_for(sequence, chars)
        prefixes[(cycle - 1) % prefixes.size] + chars[pos % size]
      when "double_character"
        chars[pos % size] * (cycle + 1)
      when "append_suffix"
        suffixes = prefixes_for(sequence, chars)
        chars[pos % size] + suffixes[(cycle - 1) % suffixes.size]
      when "none", nil
        raise Ladl::SequenceExhaustedError,
          "sequence exhausted at position #{pos + 1} (expansion_rule none)"
      else
        raise Ladl::Error, "unknown expansion_rule: #{rule.inspect}"
      end
    end

    def prefixes_for(sequence, chars)
      prefixes = Array(sequence.expansion_prefix).reject(&:empty?)
      prefixes.empty? ? chars : prefixes
    end

    # Bijective (spreadsheet-style) decomposition of a 1-based number
    # into digits of the given radix: 1 -> [1], radix -> [radix],
    # radix + 1 -> [1, 1].
    def digits(number, radix)
      digits = []
      n = number
      while n.positive?
        n -= 1
        digits.unshift((n % radix) + 1)
        n /= radix
      end
      digits
    end
  end
end
