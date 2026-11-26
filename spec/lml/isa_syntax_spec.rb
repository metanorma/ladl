# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ladl::Lml::Parser do
  # lutaml-lml spells inheritance as a body statement (`isa Base;` with
  # an optionally quoted instance name); MN 112 spells it `instance
  # Foo < Bar`. Both must load to the same profile.
  let(:mn112_syntax) do
    <<~LML
      // minimal style: one clause labeller
      instance S < LabelStyle {
        name = "S"
        labellers = ["id:clause_labeller"]
        sequences = [DecimalNumericSequence]
        templates = [ClauseTemplate]
        contexts = [DocumentContext]
      }
      instance DocumentContext < LabelContext {
        name = "document"
      }
      instance ClauseTemplate < LabelTemplate {
        pattern = "Clause %n"
      }
      instance ClauseLabeller < Labeller {
        id = "clause_labeller"
        sequence = DecimalNumericSequence
        context = DocumentContext
        type = "clause"
        template = ClauseTemplate
      }
    LML
  end

  let(:lml_syntax) do
    mn112_syntax
      .gsub('instance S < LabelStyle {', 'instance "S" { isa LabelStyle;')
      .gsub("instance DocumentContext < LabelContext {", 'instance "DocumentContext" { isa LabelContext;')
      .gsub("instance ClauseTemplate < LabelTemplate {", 'instance "ClauseTemplate" { isa LabelTemplate;')
      .gsub("instance ClauseLabeller < Labeller {", 'instance "ClauseLabeller" { isa Labeller;')
  end

  def load(text)
    Ladl::ProfileLoader.load_lml(text)
  end

  it "parses the MN 112 `< Base` spelling" do
    expect(load(mn112_syntax).style.name).to eq("S")
  end

  it "parses the lutaml-lml `isa` spelling with quoted names" do
    expect(load(lml_syntax).style.name).to eq("S")
  end

  it "produces equivalent profiles from both spellings" do
    a = load(mn112_syntax)
    b = load(lml_syntax)
    tree = Ladl::ContentElement.new(id: "doc", type: "document",
      children: [Ladl::ContentElement.new(id: "c1", type: "clause")])
    ra = Ladl::Runtime::Engine.new(a).label(tree)
    rb = Ladl::Runtime::Engine.new(b).label(tree)
    expect(ra.labels_by_element_id["c1"].value).to eq("Clause 1")
    expect(rb.labels_by_element_id["c1"].value).to eq("Clause 1")
  end
end
