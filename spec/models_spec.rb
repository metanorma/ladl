# frozen_string_literal: true

require "spec_helper"

RSpec.describe "LADL core models" do
  describe Ladl::LabelStyle do
    it "round-trips through the hash mapping" do
      style = described_class.from_hash(
        "name" => "Simple",
        "labellers" => ["id:clause_labeller"],
        "sequences" => ["ArabicNumericSequence"],
        "templates" => ["ClauseLabelTemplate"],
        "contexts" => ["DocumentContext"],
      )
      expect(style.name).to eq("Simple")
      expect(style.labellers).to eq(["id:clause_labeller"])
      expect(style.sequences).to eq(["ArabicNumericSequence"])
      hash = style.to_hash
      expect(hash["name"]).to eq("Simple")
      expect(hash["labellers"]).to eq(["id:clause_labeller"])
    end
  end

  describe Ladl::LabelContext do
    it "carries the context tree links" do
      context = described_class.from_hash(
        "name" => "clause", "parent" => "DocumentContext"
      )
      expect(context.name).to eq("clause")
      expect(context.parent).to eq("DocumentContext")
      expect(context.to_hash["parent"]).to eq("DocumentContext")
    end
  end

  describe Ladl::LabelTemplate do
    it "defaults direction to ltr" do
      template = described_class.new(pattern: "Figure %n")
      expect(template.direction).to eq("ltr")
    end

    it "carries rtl direction" do
      template = described_class.new(pattern: "%n قسم", direction: "rtl")
      expect(template.direction).to eq("rtl")
      expect(template.to_hash["direction"]).to eq("rtl")
    end

    it "reports conditional templates" do
      unconditional = described_class.new(pattern: "NOTE")
      conditional = described_class.new(
        pattern: "NOTE %n",
        condition: Ladl::LabelContextCondition.new(type: "element_count_gt", threshold: 1)
      )
      expect(unconditional).not_to be_conditional
      expect(conditional).to be_conditional
    end
  end

  describe Ladl::LabelContextCondition do
    it "evaluates element_count_gt" do
      condition = described_class.new(type: "element_count_gt", threshold: 1)
      expect(condition.evaluate(1)).to be(false)
      expect(condition.evaluate(2)).to be(true)
    end

    it "evaluates element_count_eq" do
      condition = described_class.new(type: "element_count_eq", threshold: 2)
      expect(condition.evaluate(1)).to be(false)
      expect(condition.evaluate(2)).to be(true)
    end

    it "evaluates element_count_lt" do
      condition = described_class.new(type: "element_count_lt", threshold: 3)
      expect(condition.evaluate(2)).to be(true)
      expect(condition.evaluate(3)).to be(false)
    end

    it "raises on unknown condition types" do
      condition = described_class.new(type: "element_count_gte", threshold: 1)
      expect { condition.evaluate(1) }.to raise_error(Ladl::Error, /unknown/)
    end

    it "round-trips through the hash mapping" do
      condition = described_class.from_hash(
        "type" => "element_count_gt", "threshold" => 1
      )
      expect(condition.to_hash).to eq("type" => "element_count_gt", "threshold" => 1)
    end
  end

  describe Ladl::NumericSequence do
    it "defaults initial_value and increment per MN 112" do
      sequence = described_class.new
      expect(sequence.initial_value).to eq(1)
      expect(sequence.increment).to eq(1)
      expect(sequence.char_direction).to eq("ltr")
    end

    it "computes values against the default registry" do
      sequence = described_class.new(format: "roman_upper")
      expect(sequence.value_for_position(3)).to eq("III")
    end

    it "round-trips through the hash mapping" do
      sequence = described_class.from_hash(
        "initial_value" => 2, "increment" => 2, "format" => "chinese"
      )
      expect(sequence.to_hash).to include("initial_value" => 2, "increment" => 2)
    end
  end

  describe Ladl::CharacterSequence do
    it "carries characters and expansion configuration" do
      sequence = described_class.from_hash(
        "characters" => %w[元 亨], "expansion_rule" => "prepend_prefix"
      )
      expect(sequence.characters).to eq(%w[元 亨])
      expect(sequence.value_for_position(3)).to eq("元元")
    end
  end

  describe Ladl::ContentElement do
    it "builds the content tree" do
      child = described_class.new(id: "c1", type: "clause")
      root = described_class.new(id: "doc", type: "document")
      root.add_child(child)
      expect(root.children).to eq([child])
      expect(root.each.to_a).to eq([root, child])
    end

    it "round-trips nested children through the hash mapping" do
      root = described_class.new(
        id: "doc", type: "document",
        children: [described_class.new(id: "c1", type: "clause")]
      )
      hash = root.to_hash
      expect(hash["children"].first["id"]).to eq("c1")
      rebuilt = described_class.from_hash(hash)
      expect(rebuilt.children.first.type).to eq("clause")
    end
  end

  describe Ladl::Label do
    it "carries the label value and content element reference" do
      label = described_class.new(value: "Figure 1", content_element: "f1")
      expect(label.value).to eq("Figure 1")
      expect(label.to_hash["content_element"]).to eq("f1")
    end

    it "keeps the runtime element out of serialization" do
      element = Ladl::ContentElement.new(id: "f1", type: "figure")
      label = described_class.new(value: "Figure 1")
      label.element = element
      expect(label.element).to eq(element)
      expect(label.to_hash).not_to have_key("element")
    end
  end
end
