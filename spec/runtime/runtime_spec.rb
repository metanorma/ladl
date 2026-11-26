# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ladl::Runtime::Renderer do
  it "substitutes %n with the labeller value" do
    expect(described_class.render("Figure %n", n: "1")).to eq("Figure 1")
  end

  it "substitutes %pn with the parent value" do
    expect(described_class.render("%pn.%n", n: "2", pn: "1")).to eq("1.2")
  end

  it "substitutes %parent with the parent context label" do
    expect(described_class.render("%parent, NOTE %n", n: "1", parent: "Clause 1"))
      .to eq("Clause 1, NOTE 1")
  end

  it "substitutes %self with the local label" do
    expect(described_class.render("%parent, %self", parent: "Clause 1", self: "NOTE 1"))
      .to eq("Clause 1, NOTE 1")
  end

  it "renders patterns without placeholders unchanged" do
    expect(described_class.render("—", {})).to eq("—")
  end

  it "keeps unicode text intact" do
    expect(described_class.render("%parentの%n", n: "一", parent: "二"))
      .to eq("二の一")
  end

  it "renders rtl patterns" do
    expect(described_class.render("%n قسم", n: "١")).to eq("١ قسم")
  end

  it "tolerates a missing %parent binding" do
    expect(described_class.render("%parent, %self", self: "NOTE")).to eq(", NOTE")
  end

  it "raises when %pn is used without a parent labeller" do
    expect { described_class.render("%pn.%n", n: "1") }
      .to raise_error(Ladl::ResolutionError, /no parent labeller/)
  end
end

RSpec.describe Ladl::Runtime::Resolver do
  let(:profile) { Ladl.load_profile(LADL_MN112A_PROFILE) }
  let(:resolver) { described_class.new(profile) }

  it "resolves labellers by context instance and element type" do
    expect(resolver.labeller_for_context("ClauseContext", "note").id)
      .to eq("note_labeller")
    expect(resolver.labeller_for_context("AnnexContext", "figure").id)
      .to eq("annex_figure_labeller")
  end

  it "returns nil when no labeller matches" do
    expect(resolver.labeller_for_context("SubclauseContext", "subclause")).to be_nil
    expect(resolver.labeller_for_context("ClauseContext", "subfigure")).to be_nil
  end

  it "maps context instance names to context names" do
    expect(resolver.context_name("ClauseContext")).to eq("clause")
    expect(resolver.context_name("AnnexClauseContext")).to eq("annex_clause")
  end

  it "lists child contexts by parent" do
    expect(resolver.contexts_with_parent("DocumentContext"))
      .to contain_exactly("ClauseContext", "AnnexContext")
    expect(resolver.contexts_with_parent("ClauseContext"))
      .to contain_exactly("SubclauseContext", "ListContext")
  end

  it "lists contexts named after an element type" do
    expect(resolver.contexts_named("clause")).to eq(["ClauseContext"])
    expect(resolver.contexts_named("annex")).to eq(["AnnexContext"])
    expect(resolver.contexts_named("subfigure")).to be_empty
  end

  it "resolves sequence values from the registry" do
    expect(resolver.sequence_value("AlphaUpperNumericSequence", 27)).to eq("AA")
  end

  it "returns nil for blank sequence references" do
    expect(resolver.sequence_value(nil, 1)).to be_nil
    expect(resolver.sequence_value("", 1)).to be_nil
  end

  it "raises on undefined sequences" do
    expect { resolver.sequence_value("Bogus", 1) }
      .to raise_error(Ladl::ResolutionError, /undefined sequence/)
  end

  it "computes the self-inclusive ancestor chain of a labeller" do
    expect(resolver.ancestor_chain("SubfigureLabeller"))
      .to eq(%w[SubfigureLabeller FigureLabeller])
    expect(resolver.ancestor_chain("OrderedListItemLevel3Labeller"))
      .to eq(%w[OrderedListItemLevel3Labeller OrderedListItemLevel2Labeller
        OrderedListItemLevel1Labeller])
    expect(resolver.ancestor_chain("ClauseLabeller")).to eq(["ClauseLabeller"])
  end

  it "raises on style references to undefined instances" do
    broken = Ladl::Profile.new(
      style: Ladl::LabelStyle.from_hash(
        "name" => "Broken", "contexts" => ["NowhereContext"]
      )
    )
    expect { described_class.new(broken) }
      .to raise_error(Ladl::ResolutionError, /NowhereContext/)
  end
end

RSpec.describe Ladl::Runtime::Result do
  it "looks labels up by element identity" do
    e1 = Ladl::ContentElement.new(id: "e1", type: "clause")
    e2 = Ladl::ContentElement.new(id: "e2", type: "figure")
    label1 = Ladl::Label.new(value: "Clause 1")
    label1.element = e1
    label2 = Ladl::Label.new(value: "Figure 1")
    label2.element = e2
    result = Ladl::Runtime::Result.new
    result.add(label1)
    result.add(label2)
    expect(result.size).to eq(2)
    expect(result.local_for(e1)).to eq("Clause 1")
    expect(result.global_for(e1)).to be_nil
    expect(result.label_for(e2).value).to eq("Figure 1")
    expect(result.map(&:value)).to eq(["Clause 1", "Figure 1"])
    expect(result.labels_by_element_id).to have_key("e1")
  end
end
