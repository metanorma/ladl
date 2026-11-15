# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ladl::Sequences do
  def seq_value(name, position)
    described_class.value_for(Ladl::Sequences::Registry.lookup(name), position)
  end

  describe "default sequences (MN 112 runtime requirements)" do
    it "provides decimal numbers" do
      expect(seq_value("DecimalNumericSequence", 1)).to eq("1")
      expect(seq_value("DecimalNumericSequence", 12)).to eq("12")
    end

    it "maps ArabicNumericSequence to Western digits (profile-compatible)" do
      expect(seq_value("ArabicNumericSequence", 1)).to eq("1")
      expect(seq_value("ArabicNumericSequence", 27)).to eq("27")
    end

    it "provides Arabic-script numerals under ArabicIndicNumericSequence" do
      expect(seq_value("ArabicIndicNumericSequence", 1)).to eq("١")
      expect(seq_value("ArabicIndicNumericSequence", 9)).to eq("٩")
      expect(seq_value("ArabicIndicNumericSequence", 12)).to eq("١٢")
    end

    it "provides uppercase Roman numerals" do
      expect(seq_value("RomanUpperNumericSequence", 1)).to eq("I")
      expect(seq_value("RomanUpperNumericSequence", 4)).to eq("IV")
      expect(seq_value("RomanUpperNumericSequence", 9)).to eq("IX")
      expect(seq_value("RomanUpperNumericSequence", 14)).to eq("XIV")
      expect(seq_value("RomanUpperNumericSequence", 40)).to eq("XL")
      expect(seq_value("RomanUpperNumericSequence", 1994)).to eq("MCMXCIV")
    end

    it "provides lowercase Roman numerals" do
      expect(seq_value("RomanLowerNumericSequence", 3)).to eq("iii")
      expect(seq_value("RomanLowerNumericSequence", 38)).to eq("xxxviii")
    end

    it "provides uppercase letters with spreadsheet expansion" do
      expect(seq_value("AlphaUpperNumericSequence", 1)).to eq("A")
      expect(seq_value("AlphaUpperNumericSequence", 26)).to eq("Z")
      expect(seq_value("AlphaUpperNumericSequence", 27)).to eq("AA")
      expect(seq_value("AlphaUpperNumericSequence", 28)).to eq("AB")
      expect(seq_value("AlphaUpperNumericSequence", 52)).to eq("AZ")
      expect(seq_value("AlphaUpperNumericSequence", 53)).to eq("BA")
    end

    it "provides lowercase letters (Annex AA convention)" do
      expect(seq_value("AlphaLowerNumericSequence", 1)).to eq("a")
      expect(seq_value("AlphaLowerNumericSequence", 27)).to eq("aa")
    end

    it "provides Chinese numerals" do
      expect(seq_value("ChineseNumericSequence", 1)).to eq("一")
      expect(seq_value("ChineseNumericSequence", 2)).to eq("二")
      expect(seq_value("ChineseNumericSequence", 9)).to eq("九")
      expect(seq_value("ChineseNumericSequence", 10)).to eq("十")
      expect(seq_value("ChineseNumericSequence", 11)).to eq("十一")
      expect(seq_value("ChineseNumericSequence", 21)).to eq("二十一")
      expect(seq_value("ChineseNumericSequence", 100)).to eq("一百")
      expect(seq_value("ChineseNumericSequence", 108)).to eq("一百八")
    end

    it "provides Japanese numerals" do
      expect(seq_value("JapaneseNumericSequence", 1)).to eq("一")
      expect(seq_value("JapaneseNumericSequence", 2)).to eq("二")
      expect(seq_value("JapaneseNumericSequence", 3)).to eq("三")
      expect(seq_value("JapaneseNumericSequence", 23)).to eq("二十三")
    end

    it "provides Korean numerals" do
      expect(seq_value("KoreanNumericSequence", 1)).to eq("일")
      expect(seq_value("KoreanNumericSequence", 2)).to eq("이")
      expect(seq_value("KoreanNumericSequence", 3)).to eq("삼")
      expect(seq_value("KoreanNumericSequence", 14)).to eq("십사")
    end

    it "provides uppercase Cyrillic characters" do
      expect(seq_value("CyrillicUpperCharacterSequence", 1)).to eq("А")
      expect(seq_value("CyrillicUpperCharacterSequence", 7)).to eq("Ж")
      expect(seq_value("CyrillicUpperCharacterSequence", 32)).to eq("Я")
      expect(seq_value("CyrillicUpperCharacterSequence", 33)).to eq("АА")
    end

    it "provides lowercase Cyrillic characters" do
      expect(seq_value("CyrillicLowerCharacterSequence", 2)).to eq("б")
    end

    it "provides uppercase Greek characters" do
      expect(seq_value("GreekUpperCharacterSequence", 1)).to eq("Α")
      expect(seq_value("GreekUpperCharacterSequence", 8)).to eq("Θ")
      expect(seq_value("GreekUpperCharacterSequence", 24)).to eq("Ω")
      expect(seq_value("GreekUpperCharacterSequence", 25)).to eq("ΑΑ")
    end

    it "provides lowercase Greek characters" do
      expect(seq_value("GreekLowerCharacterSequence", 3)).to eq("γ")
    end

    it "provides Hebrew letters" do
      expect(seq_value("HebrewNumericSequence", 1)).to eq("א")
      expect(seq_value("HebrewNumericSequence", 2)).to eq("ב")
      expect(seq_value("HebrewNumericSequence", 22)).to eq("ת")
      expect(seq_value("HebrewNumericSequence", 23)).to eq("אא")
    end
  end

  describe "profile-defined sequence instances (MN 112 NumericSequence)" do
    it "supports base_sequence, initial_value and increment (jump sequences)" do
      triple = Ladl::NumericSequence.new(
        base_sequence: "ArabicIndicNumericSequence",
        initial_value: 1, increment: 3
      )
      expect(described_class.value_for(triple, 1)).to eq("١")
      expect(described_class.value_for(triple, 2)).to eq("٤")
      expect(described_class.value_for(triple, 3)).to eq("٧")
    end

    it "supports even-only custom sequences" do
      even = Ladl::NumericSequence.new(
        base_sequence: "ChineseNumericSequence",
        initial_value: 2, increment: 2
      )
      expect(described_class.value_for(even, 1)).to eq("二")
      expect(described_class.value_for(even, 4)).to eq("八")
    end

    it "raises on undefined base sequences" do
      broken = Ladl::NumericSequence.new(base_sequence: "Nope", format: "decimal")
      expect { described_class.value_for(broken, 1) }
        .to raise_error(Ladl::ResolutionError, /base sequence/)
    end

    it "resolves base sequences through the provided lookup" do
      base = Ladl::NumericSequence.new(format: "roman_upper")
      derived = Ladl::NumericSequence.new(base_sequence: "X", initial_value: 4)
      value = described_class.value_for(derived, 1, lookup: ->(_n) { base })
      expect(value).to eq("IV")
    end

    it "expands bijectively when cycle_length is set" do
      cycled = Ladl::NumericSequence.new(format: "decimal", cycle_length: 10)
      expect(described_class.value_for(cycled, 1)).to eq("1")
      expect(described_class.value_for(cycled, 10)).to eq("10")
      expect(described_class.value_for(cycled, 11)).to eq("11")
    end
  end

  describe "CharacterSequence expansion rules" do
    let(:yijing) do
      Ladl::CharacterSequence.new(
        characters: %w[元 亨 利 貞],
        expansion_rule: "prepend_prefix",
        expansion_prefix: %w[乾 坤 巽 震],
      )
    end

    it "produces the base characters first" do
      expect(described_class.value_for(yijing, 1)).to eq("元")
      expect(described_class.value_for(yijing, 4)).to eq("貞")
    end

    it "prepends prefix characters after completion (MN 112 YiJing example)" do
      expect(described_class.value_for(yijing, 5)).to eq("乾元")
      expect(described_class.value_for(yijing, 6)).to eq("乾亨")
      expect(described_class.value_for(yijing, 8)).to eq("乾貞")
      expect(described_class.value_for(yijing, 9)).to eq("坤元")
    end

    it "defaults the prefix to the characters themselves (spreadsheet behavior)" do
      alpha = Ladl::CharacterSequence.new(
        characters: %w[a b c], expansion_rule: "prepend_prefix"
      )
      expect(described_class.value_for(alpha, 4)).to eq("aa")
      expect(described_class.value_for(alpha, 6)).to eq("ac")
    end

    it "doubles characters for the double_character rule" do
      greek = Ladl::CharacterSequence.new(
        characters: %w[α β γ δ ε ζ η θ], expansion_rule: "double_character"
      )
      expect(described_class.value_for(greek, 8)).to eq("θ")
      expect(described_class.value_for(greek, 9)).to eq("αα")
      expect(described_class.value_for(greek, 10)).to eq("ββ")
    end

    it "repeats the label character for the repeat_label rule" do
      repeat = Ladl::CharacterSequence.new(
        characters: %w[a b c], expansion_rule: "repeat_label"
      )
      expect(described_class.value_for(repeat, 4)).to eq("a")
      expect(described_class.value_for(repeat, 5)).to eq("b")
    end

    it "appends a suffix character for the append_suffix rule" do
      append = Ladl::CharacterSequence.new(
        characters: %w[元 亨 利 貞], expansion_rule: "append_suffix",
        expansion_prefix: %w[乾 坤]
      )
      expect(described_class.value_for(append, 5)).to eq("元乾")
      expect(described_class.value_for(append, 6)).to eq("亨乾")
    end

    it "exhausts with rule none" do
      fixed = Ladl::CharacterSequence.new(
        characters: %w[a b c], expansion_rule: "none"
      )
      expect { described_class.value_for(fixed, 4) }
        .to raise_error(Ladl::SequenceExhaustedError)
    end

    it "exhausts without an expansion rule" do
      fixed = Ladl::CharacterSequence.new(characters: %w[a b c])
      expect { described_class.value_for(fixed, 5) }
        .to raise_error(Ladl::SequenceExhaustedError)
    end

    it "raises on an unknown expansion rule" do
      weird = Ladl::CharacterSequence.new(
        characters: %w[a], expansion_rule: "explode"
      )
      expect { described_class.value_for(weird, 2) }
        .to raise_error(Ladl::Error, /unknown expansion_rule/)
    end
  end

  describe Ladl::Sequences::Formatters do
    it "rejects non-positive numbers" do
      expect { described_class.format("decimal", 0) }
        .to raise_error(Ladl::Error, /positive/)
    end

    it "rejects unknown formats" do
      expect { described_class.format("klingon", 1) }
        .to raise_error(Ladl::Error, /unknown labeling format/)
    end
  end
end
